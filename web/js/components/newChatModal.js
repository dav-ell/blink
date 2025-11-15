import { apiClient } from '../api/client.js';
import { Device } from '../models/device.js';

export class NewChatModal {
    constructor() {
        this.isOpen = false;
        this.chatLocation = 'local'; // 'local' or 'remote'
        this.devices = [];
        this.selectedDevice = null;
        this.isLoadingDevices = false;
        this.isCreating = false;
        this.errorMessage = '';
        
        this.modalElement = null;
        this.onChatCreated = null; // Callback when chat is created
        
        this.init();
    }

    init() {
        // Create modal HTML
        this.modalElement = this.createModalHTML();
        document.body.appendChild(this.modalElement);
        
        // Bind event listeners
        this.bindEvents();
    }

    createModalHTML() {
        const overlay = document.createElement('div');
        overlay.className = 'modal-overlay hidden';
        overlay.id = 'newChatModal';
        
        overlay.innerHTML = `
            <div class="modal">
                <div class="modal-header">
                    <h2 class="modal-title">New Chat</h2>
                    <button class="modal-close" id="closeModal" aria-label="Close">&times;</button>
                </div>
                
                <div class="modal-body">
                    <!-- Segmented Control for Local/Remote -->
                    <div class="segmented-control">
                        <button class="segmented-control-option active" data-location="local">
                            💻 Local
                        </button>
                        <button class="segmented-control-option" data-location="remote">
                            📡 Remote
                        </button>
                    </div>
                    
                    <!-- Error Message -->
                    <div id="modalError" class="error-message" style="display: none;">
                        <span>⚠️</span>
                        <div id="modalErrorText"></div>
                    </div>
                    
                    <!-- Remote Configuration -->
                    <div id="remoteConfig" style="display: none;">
                        <!-- Device Selection -->
                        <div class="form-group">
                            <label class="form-label" for="deviceSelect">
                                Device
                                <button class="btn-icon" id="refreshDevices" style="margin-left: 8px;" title="Refresh devices">
                                    🔄
                                </button>
                            </label>
                            <select class="select" id="deviceSelect">
                                <option value="">Loading devices...</option>
                            </select>
                            <span class="form-help">Select a remote device to run the chat on</span>
                        </div>
                        
                        <!-- Working Directory -->
                        <div class="form-group">
                            <label class="form-label" for="workingDirectory">Working Directory</label>
                            <input 
                                type="text" 
                                class="input" 
                                id="workingDirectory" 
                                placeholder="/path/to/project"
                                value="/"
                            >
                            <span class="form-help">The directory where cursor-agent will run</span>
                        </div>
                    </div>
                    
                    <!-- Optional Chat Name -->
                    <div class="form-group">
                        <label class="form-label" for="chatName">Chat Name (Optional)</label>
                        <input 
                            type="text" 
                            class="input" 
                            id="chatName" 
                            placeholder="My Project Chat"
                        >
                    </div>
                </div>
                
                <div class="modal-footer">
                    <button class="btn btn-secondary" id="cancelBtn">Cancel</button>
                    <button class="btn btn-primary" id="createBtn">
                        <span id="createBtnText">Create Chat</span>
                        <div class="spinner" id="createSpinner" style="display: none;"></div>
                    </button>
                </div>
            </div>
        `;
        
        return overlay;
    }

    bindEvents() {
        // Close modal
        const closeBtn = this.modalElement.querySelector('#closeModal');
        const cancelBtn = this.modalElement.querySelector('#cancelBtn');
        closeBtn.addEventListener('click', () => this.close());
        cancelBtn.addEventListener('click', () => this.close());
        
        // Close on overlay click (but not on modal content click)
        this.modalElement.addEventListener('click', (e) => {
            if (e.target === this.modalElement) {
                this.close();
            }
        });
        
        // Keyboard shortcuts
        document.addEventListener('keydown', (e) => {
            if (this.isOpen && e.key === 'Escape') {
                this.close();
            }
        });
        
        // Segmented control (tab switching)
        const segmentedOptions = this.modalElement.querySelectorAll('.segmented-control-option');
        segmentedOptions.forEach(option => {
            option.addEventListener('click', (e) => {
                const location = e.target.dataset.location;
                this.switchLocation(location);
            });
        });
        
        // Refresh devices button
        const refreshBtn = this.modalElement.querySelector('#refreshDevices');
        refreshBtn.addEventListener('click', () => this.loadDevices());
        
        // Device selection
        const deviceSelect = this.modalElement.querySelector('#deviceSelect');
        deviceSelect.addEventListener('change', (e) => {
            const deviceId = e.target.value;
            this.selectedDevice = this.devices.find(d => d.id === deviceId) || null;
        });
        
        // Create button
        const createBtn = this.modalElement.querySelector('#createBtn');
        createBtn.addEventListener('click', () => this.createChat());
    }

    async open() {
        this.isOpen = true;
        this.modalElement.classList.remove('hidden');
        this.resetForm();
        
        // Load devices if remote tab
        if (this.chatLocation === 'remote') {
            await this.loadDevices();
        }
    }

    close() {
        this.isOpen = false;
        this.modalElement.classList.add('hidden');
        this.resetForm();
    }

    resetForm() {
        // Reset state
        this.chatLocation = 'local';
        this.errorMessage = '';
        this.isCreating = false;
        
        // Reset UI
        const segmentedOptions = this.modalElement.querySelectorAll('.segmented-control-option');
        segmentedOptions.forEach(opt => {
            opt.classList.toggle('active', opt.dataset.location === 'local');
        });
        
        const remoteConfig = this.modalElement.querySelector('#remoteConfig');
        remoteConfig.style.display = 'none';
        
        this.modalElement.querySelector('#chatName').value = '';
        this.modalElement.querySelector('#workingDirectory').value = '/';
        
        this.hideError();
        this.setCreatingState(false);
    }

    switchLocation(location) {
        this.chatLocation = location;
        
        // Update tab active state
        const segmentedOptions = this.modalElement.querySelectorAll('.segmented-control-option');
        segmentedOptions.forEach(option => {
            option.classList.toggle('active', option.dataset.location === location);
        });
        
        // Show/hide remote configuration
        const remoteConfig = this.modalElement.querySelector('#remoteConfig');
        if (location === 'remote') {
            remoteConfig.style.display = 'block';
            this.loadDevices();
        } else {
            remoteConfig.style.display = 'none';
        }
        
        this.hideError();
    }

    async loadDevices() {
        if (this.isLoadingDevices) return;
        
        this.isLoadingDevices = true;
        const deviceSelect = this.modalElement.querySelector('#deviceSelect');
        deviceSelect.disabled = true;
        deviceSelect.innerHTML = '<option value="">Loading devices...</option>';
        
        try {
            const response = await apiClient.listDevices({ includeInactive: false });
            this.devices = response.devices.map(d => Device.fromJson(d));
            
            // Populate select options
            if (this.devices.length === 0) {
                deviceSelect.innerHTML = '<option value="">No devices available</option>';
                this.showError('No remote devices found. Please add a device first.');
            } else {
                deviceSelect.innerHTML = this.devices.map(device => {
                    const statusIcon = device.statusIcon;
                    return `<option value="${device.id}">${statusIcon} ${device.name} (${device.statusDisplayName})</option>`;
                }).join('');
                
                // Auto-select first online device
                const firstOnlineDevice = this.devices.find(d => d.isOnline) || this.devices[0];
                if (firstOnlineDevice) {
                    deviceSelect.value = firstOnlineDevice.id;
                    this.selectedDevice = firstOnlineDevice;
                }
            }
            
            deviceSelect.disabled = false;
            this.isLoadingDevices = false;
        } catch (error) {
            console.error('Failed to load devices:', error);
            deviceSelect.innerHTML = '<option value="">Failed to load devices</option>';
            deviceSelect.disabled = false;
            this.isLoadingDevices = false;
            this.showError(`Failed to load devices: ${error.message}`);
        }
    }

    async createChat() {
        if (this.isCreating) return;
        
        this.hideError();
        
        // Validate inputs
        if (this.chatLocation === 'remote') {
            if (!this.selectedDevice) {
                this.showError('Please select a device');
                return;
            }
            
            const workingDirectory = this.modalElement.querySelector('#workingDirectory').value.trim();
            if (!workingDirectory) {
                this.showError('Working directory is required');
                return;
            }
        }
        
        this.setCreatingState(true);
        
        try {
            let chatId;
            const chatName = this.modalElement.querySelector('#chatName').value.trim() || null;
            
            if (this.chatLocation === 'local') {
                // Create local chat
                const response = await apiClient.createLocalChat(chatName);
                chatId = response.chat_id;
            } else {
                // Create remote chat
                const workingDirectory = this.modalElement.querySelector('#workingDirectory').value.trim();
                const response = await apiClient.createRemoteChat(
                    this.selectedDevice.id,
                    workingDirectory,
                    chatName
                );
                chatId = response.chat_id;
            }
            
            // Success! Close modal and notify
            this.setCreatingState(false);
            this.close();
            
            if (this.onChatCreated) {
                this.onChatCreated(chatId, this.chatLocation);
            }
            
            // Redirect to chat detail page
            window.location.href = `chat.html?id=${chatId}`;
            
        } catch (error) {
            console.error('Failed to create chat:', error);
            this.setCreatingState(false);
            this.showError(`Failed to create chat: ${error.message}`);
        }
    }

    setCreatingState(isCreating) {
        this.isCreating = isCreating;
        const createBtn = this.modalElement.querySelector('#createBtn');
        const createBtnText = this.modalElement.querySelector('#createBtnText');
        const createSpinner = this.modalElement.querySelector('#createSpinner');
        
        createBtn.disabled = isCreating;
        createBtnText.style.display = isCreating ? 'none' : 'inline';
        createSpinner.style.display = isCreating ? 'inline-block' : 'none';
    }

    showError(message) {
        this.errorMessage = message;
        const errorEl = this.modalElement.querySelector('#modalError');
        const errorText = this.modalElement.querySelector('#modalErrorText');
        errorText.textContent = message;
        errorEl.style.display = 'flex';
    }

    hideError() {
        this.errorMessage = '';
        const errorEl = this.modalElement.querySelector('#modalError');
        errorEl.style.display = 'none';
    }

    destroy() {
        if (this.modalElement && this.modalElement.parentNode) {
            this.modalElement.parentNode.removeChild(this.modalElement);
        }
    }
}

