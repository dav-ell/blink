import { apiClient } from '../api/client.js';
import { Message } from '../models/message.js';
import { Chat } from '../models/chat.js';
import { createMessageBubble } from '../components/messageBubble.js';
import { themeManager } from '../utils/theme.js';
import { Formatter } from '../utils/formatter.js';
import { ChatLocation } from '../models/device.js';

class ChatDetailPage {
    constructor() {
        this.chatId = this.getChatIdFromUrl();
        this.messages = [];
        this.chatMetadata = null;
        this.chat = null;
        this.isSending = false;
        this.optimisticMessages = []; // Track messages not yet in backend
        
        if (!this.chatId) {
            alert('No chat ID provided');
            window.location.href = 'index.html';
            return;
        }

        this.initElements();
        this.initTheme();
        this.attachEventListeners();
        this.loadChat();
    }

    getChatIdFromUrl() {
        const params = new URLSearchParams(window.location.search);
        return params.get('id');
    }

    initTheme() {
        // Remove preload class after a short delay
        setTimeout(() => {
            document.body.classList.remove('preload');
        }, 100);

        this.updateThemeIcon();
    }

    initElements() {
        this.messagesContainerEl = document.getElementById('messagesContainer');
        this.messagesListEl = document.getElementById('messagesList');
        this.loadingStateEl = document.getElementById('loadingState');
        this.emptyStateEl = document.getElementById('emptyState');
        this.errorStateEl = document.getElementById('errorState');
        this.errorMessageEl = document.getElementById('errorMessage');
        
        this.chatTitleEl = document.getElementById('chatTitle');
        this.chatStatsEl = document.getElementById('chatStats');
        this.messageCountEl = document.getElementById('messageCount');
        this.linesChangedEl = document.getElementById('linesChanged');
        this.lastUpdatedEl = document.getElementById('lastUpdated');
        
        this.messageInputEl = document.getElementById('messageInput');
        this.sendBtnEl = document.getElementById('sendBtn');
        this.backBtnEl = document.getElementById('backBtn');
        this.refreshBtnEl = document.getElementById('refreshBtn');
        this.themeToggleEl = document.getElementById('themeToggle');
        this.retryBtnEl = document.getElementById('retryBtn');
    }

    attachEventListeners() {
        // Back button
        this.backBtnEl.addEventListener('click', () => {
            window.location.href = 'index.html';
        });

        // Refresh button
        this.refreshBtnEl.addEventListener('click', () => {
            this.loadChat();
        });

        // Theme toggle
        this.themeToggleEl.addEventListener('click', () => {
            themeManager.toggle();
            this.updateThemeIcon();
        });

        // Retry button
        this.retryBtnEl.addEventListener('click', () => {
            this.loadChat();
        });

        // Message input auto-resize
        this.messageInputEl.addEventListener('input', () => {
            this.autoResizeTextarea();
        });

        // Send message
        this.sendBtnEl.addEventListener('click', () => {
            this.sendMessage();
        });

        // Send on Enter (but Shift+Enter for new line)
        this.messageInputEl.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                this.sendMessage();
            }
        });
    }

    updateThemeIcon() {
        const icon = this.themeToggleEl.querySelector('.theme-icon');
        icon.textContent = themeManager.isDark() ? '☀️' : '🌙';
    }

    autoResizeTextarea() {
        this.messageInputEl.style.height = 'auto';
        this.messageInputEl.style.height = this.messageInputEl.scrollHeight + 'px';
    }

    async loadChat() {
        this.showLoading();

        try {
            const response = await apiClient.getChatMessages(this.chatId, {
                includeMetadata: true,
                includeContent: true,
            });

            this.messages = response.messages.map(msgData => Message.fromJson(msgData));
            this.chatMetadata = response.metadata;
            
            // Create Chat object from metadata to detect if remote
            if (this.chatMetadata) {
                this.chat = Chat.fromJson({
                    ...this.chatMetadata,
                    chat_id: this.chatId,
                    messages: this.messages,
                });
            }

            // Remove optimistic messages that now exist in the real messages
            // Match by text content
            this.optimisticMessages = this.optimisticMessages.filter(optMsg => {
                const exists = this.messages.some(realMsg => 
                    realMsg.content.trim() === optMsg.content.trim() &&
                    realMsg.role === optMsg.role
                );
                return !exists;
            });

            this.updateChatHeader();
            this.renderMessages();
            this.scrollToBottom();

            if (this.getAllMessages().length === 0) {
                this.showEmpty();
            }
        } catch (error) {
            console.error('Failed to load chat:', error);
            this.showError(error.message);
        }
    }

    getAllMessages() {
        // Combine real messages with optimistic ones
        return [...this.messages, ...this.optimisticMessages];
    }

    updateChatHeader() {
        if (this.chatMetadata) {
            this.chatTitleEl.textContent = this.chatMetadata.name || 'Untitled Chat';
            
            // Build stats HTML
            let statsHtml = '';
            
            const messageCount = this.chatMetadata.message_count || this.messages.length;
            statsHtml += `<span id="messageCount">${messageCount} ${Formatter.pluralize(messageCount, 'message')}</span>`;
            
            const linesAdded = this.chatMetadata.total_lines_added || 0;
            const linesRemoved = this.chatMetadata.total_lines_removed || 0;
            if (linesAdded > 0 || linesRemoved > 0) {
                statsHtml += `<span id="linesChanged">+${linesAdded} -${linesRemoved}</span>`;
            }
            
            if (this.chatMetadata.last_updated_at_iso) {
                statsHtml += `<span id="lastUpdated">${Formatter.formatTime(this.chatMetadata.last_updated_at_iso)}</span>`;
            }
            
            // Add remote info if chat is remote
            if (this.chat && this.chat.isRemote && this.chat.remoteInfo) {
                const remoteInfo = this.chat.remoteInfo;
                statsHtml = `
                    <div style="display: flex; align-items: center; gap: 12px; flex-wrap: wrap;">
                        <span class="badge badge-remote" style="font-size: 11px;">
                            📡 ${escapeHtml(remoteInfo.deviceName)}
                        </span>
                        <span class="device-status-indicator" data-status="${remoteInfo.deviceStatus}" style="font-size: 11px;">
                            ${remoteInfo.statusIcon} ${remoteInfo.deviceStatus}
                        </span>
                        <span title="${escapeHtml(remoteInfo.workingDirectory)}" style="font-size: 11px;">
                            📁 ${escapeHtml(remoteInfo.workingDirectory)}
                        </span>
                    </div>
                    <div style="margin-top: 4px;">
                        ${statsHtml}
                    </div>
                `;
            }
            
            this.chatStatsEl.innerHTML = statsHtml;
        }
    }

    isRemoteChat() {
        return this.chat && this.chat.isRemote;
    }

    renderMessages() {
        // Hide all states
        this.loadingStateEl.classList.add('hidden');
        this.emptyStateEl.classList.add('hidden');
        this.errorStateEl.classList.add('hidden');

        // Clear existing messages (but keep state elements)
        const existingMessages = this.messagesListEl.querySelectorAll('.message-bubble, .tool-call-box, .thinking-box');
        existingMessages.forEach(msg => msg.remove());

        const allMessages = this.getAllMessages();
        if (allMessages.length === 0) {
            this.showEmpty();
            return;
        }

        // Render all messages (real + optimistic)
        allMessages.forEach(message => {
            const bubble = createMessageBubble(message);
            this.messagesListEl.appendChild(bubble);
        });
    }

    scrollToBottom(smooth = true) {
        setTimeout(() => {
            this.messagesContainerEl.scrollTo({
                top: this.messagesContainerEl.scrollHeight,
                behavior: smooth ? 'smooth' : 'auto',
            });
        }, 100);
    }

    async sendMessage() {
        const messageText = this.messageInputEl.value.trim();
        if (!messageText || this.isSending) return;

        this.isSending = true;
        this.sendBtnEl.disabled = true;
        this.messageInputEl.disabled = true;

        // Clear input
        this.messageInputEl.value = '';
        this.autoResizeTextarea();

        // Detect if this is a remote chat
        const isRemote = this.isRemoteChat();

        // Store the initial message count (includes optimistic)
        const initialMessageCount = this.getAllMessages().length;

        // Add optimistic user message
        const tempMessage = new Message({
            bubble_id: `temp-${Date.now()}`,
            text: messageText,
            type_label: 'user',
            created_at: new Date().toISOString(),
            status: 'sending',
            is_remote: isRemote,
            sent_at: new Date().toISOString(),
        });
        this.optimisticMessages.push(tempMessage);
        this.renderMessages();
        this.scrollToBottom();

        try {
            // Update status to processing for remote messages
            if (isRemote) {
                tempMessage.status = 'processing';
                tempMessage.deliveredAt = new Date();
                this.renderMessages();
            }

            // Send message to appropriate endpoint (local or remote)
            if (isRemote) {
                await apiClient.sendRemoteMessage(this.chatId, messageText);
            } else {
                await apiClient.sendMessage(this.chatId, messageText, false);
            }

            // Update status to completed for remote messages
            if (isRemote) {
                tempMessage.status = 'completed';
                tempMessage.completedAt = new Date();
                this.renderMessages();
            }

            // Poll for new messages instead of single reload
            this.pollForNewMessages(initialMessageCount, isRemote);
        } catch (error) {
            console.error('Failed to send message:', error);
            
            // Update message status to failed
            tempMessage.status = 'failed';
            tempMessage.errorMessage = error.message;
            this.renderMessages();
            
            // Show error notification
            this.showNotification('Failed to send message: ' + error.message, 'error');
        } finally {
            this.isSending = false;
            this.sendBtnEl.disabled = false;
            this.messageInputEl.disabled = false;
            this.messageInputEl.focus();
        }
    }

    async pollForNewMessages(initialCount, isRemote = false) {
        // Poll more aggressively for remote messages (up to 10 minutes)
        const maxAttempts = isRemote ? 120 : 10;  // 120 * 5s = 10 minutes for remote
        const interval = isRemote ? 5000 : 1000;   // 5 seconds for remote, 1 second for local
        let attempts = 0;

        const poll = async () => {
            attempts++;
            
            try {
                const response = await apiClient.getChatMessages(this.chatId);
                const apiMessageCount = response.messages.length;
                
                // Check if we have new messages in the API (beyond optimistic ones)
                // We compare against the real message count from before sending
                if (apiMessageCount > this.messages.length) {
                    // New messages arrived, reload the full chat
                    await this.loadChat();
                    return;
                }
                
                // Continue polling if we haven't exceeded max attempts
                if (attempts < maxAttempts) {
                    setTimeout(poll, interval);
                } else {
                    // Timeout reached, do final reload
                    await this.loadChat();
                }
            } catch (error) {
                console.error('Error polling for messages:', error);
                // On error, stop polling and do final reload
                await this.loadChat();
            }
        };

        // Start polling after a short delay
        setTimeout(poll, interval);
    }

    showLoading() {
        this.loadingStateEl.classList.remove('hidden');
        this.emptyStateEl.classList.add('hidden');
        this.errorStateEl.classList.add('hidden');
        
        // Remove existing messages
        const existingMessages = this.messagesListEl.querySelectorAll('.message-bubble, .tool-call-box, .thinking-box');
        existingMessages.forEach(msg => msg.remove());
    }

    showEmpty() {
        this.loadingStateEl.classList.add('hidden');
        this.emptyStateEl.classList.remove('hidden');
        this.errorStateEl.classList.add('hidden');
    }

    showError(message) {
        this.loadingStateEl.classList.add('hidden');
        this.emptyStateEl.classList.add('hidden');
        this.errorStateEl.classList.remove('hidden');
        this.errorMessageEl.textContent = message;
    }

    showNotification(message, type = 'info') {
        const notification = document.createElement('div');
        notification.className = type === 'error' ? 'error-message' : 'success-message';
        notification.style.position = 'fixed';
        notification.style.top = '20px';
        notification.style.left = '50%';
        notification.style.transform = 'translateX(-50%)';
        notification.style.zIndex = '1000';
        notification.style.minWidth = '300px';
        notification.textContent = message;

        document.body.appendChild(notification);

        setTimeout(() => {
            notification.remove();
        }, 3000);
    }
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Initialize the page
document.addEventListener('DOMContentLoaded', () => {
    new ChatDetailPage();
});

