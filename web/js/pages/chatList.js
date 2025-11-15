import { apiClient } from '../api/client.js';
import { Chat } from '../models/chat.js';
import { createChatCard } from '../components/chatCard.js';
import { themeManager } from '../utils/theme.js';
import { ChatLocation } from '../models/device.js';
import { NewChatModal } from '../components/newChatModal.js';

class ChatListPage {
    constructor() {
        this.chats = [];
        this.localChats = [];
        this.remoteChats = [];
        this.cursorAgentChats = [];
        this.filteredChats = [];
        this.currentFilter = 'all';
        this.searchQuery = '';
        
        this.initElements();
        this.initTheme();
        this.initNewChatModal();
        this.attachEventListeners();
        this.loadChats();
    }

    initNewChatModal() {
        // Create and initialize the new chat modal
        this.newChatModal = new NewChatModal();
        
        // Set callback for when chat is created
        this.newChatModal.onChatCreated = (chatId, location) => {
            console.log(`Chat created: ${chatId} (${location})`);
            // Optionally reload chats to show the new one
            // this.loadChats();
        };
    }

    initTheme() {
        // Remove preload class after a short delay to enable transitions
        setTimeout(() => {
            document.body.classList.remove('preload');
        }, 100);

        // Update theme icon
        this.updateThemeIcon();
    }

    initElements() {
        this.chatListEl = document.getElementById('chatList');
        this.loadingStateEl = document.getElementById('loadingState');
        this.emptyStateEl = document.getElementById('emptyState');
        this.errorStateEl = document.getElementById('errorState');
        this.errorMessageEl = document.getElementById('errorMessage');
        this.searchInputEl = document.getElementById('searchInput');
        this.themeToggleEl = document.getElementById('themeToggle');
        this.retryBtnEl = document.getElementById('retryBtn');
        this.filterBtns = document.querySelectorAll('.filter-btn');
        this.newChatFabEl = document.getElementById('newChatFab');
    }

    attachEventListeners() {
        // Theme toggle
        this.themeToggleEl.addEventListener('click', () => {
            themeManager.toggle();
            this.updateThemeIcon();
        });

        // Search
        this.searchInputEl.addEventListener('input', (e) => {
            this.searchQuery = e.target.value.toLowerCase();
            this.filterChats();
        });

        // Filters
        this.filterBtns.forEach(btn => {
            btn.addEventListener('click', () => {
                this.filterBtns.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                this.currentFilter = btn.dataset.filter;
                this.filterChats();
            });
        });

        // Retry button
        this.retryBtnEl.addEventListener('click', () => {
            this.loadChats();
        });

        // New chat FAB
        this.newChatFabEl.addEventListener('click', () => {
            this.newChatModal.open();
        });
    }

    updateThemeIcon() {
        const icon = this.themeToggleEl.querySelector('.theme-icon');
        icon.textContent = themeManager.isDark() ? '☀️' : '🌙';
    }

    async loadChats() {
        this.showLoading();

        try {
            // Fetch local chats
            const localResponse = await apiClient.listChats({
                includeArchived: true,
                sortBy: 'last_updated',
            });
            this.localChats = localResponse.chats.map(chatData => Chat.fromJson(chatData));

            // Fetch remote chats
            let remoteChats = [];
            try {
                const remoteResponse = await apiClient.listRemoteChats();
                remoteChats = remoteResponse.chats || remoteResponse || [];
                this.remoteChats = remoteChats.map(chatData => {
                    // Mark as remote and add location
                    const enrichedData = {
                        ...chatData,
                        location: ChatLocation.REMOTE,
                    };
                    return Chat.fromJson(enrichedData);
                });
            } catch (remoteError) {
                console.warn('Failed to load remote chats:', remoteError);
                this.remoteChats = [];
            }

            // Fetch cursor-agent chats
            let cursorAgentChats = [];
            try {
                const cursorAgentResponse = await apiClient.listCursorAgentChats({
                    includeArchived: true,
                    sortBy: 'last_updated',
                });
                cursorAgentChats = cursorAgentResponse.chats || [];
                this.cursorAgentChats = cursorAgentChats.map(chatData => Chat.fromJson(chatData));
                
                // Debug: log first cursor-agent chat
                if (this.cursorAgentChats.length > 0) {
                    const firstChat = this.cursorAgentChats[0];
                    console.log('First cursor-agent chat:', {
                        id: firstChat.id,
                        title: firstChat.title,
                        format: firstChat.format,
                        isCursorAgent: firstChat.isCursorAgent,
                        location: firstChat.location
                    });
                }
            } catch (cursorAgentError) {
                console.warn('Failed to load cursor-agent chats:', cursorAgentError);
                this.cursorAgentChats = [];
            }

            // Merge all chats and sort by last updated
            this.chats = [...this.localChats, ...this.remoteChats, ...this.cursorAgentChats];
            this.chats.sort((a, b) => b.lastMessageAt - a.lastMessageAt);

            this.filterChats();

            if (this.chats.length === 0) {
                this.showEmpty();
            }
        } catch (error) {
            console.error('Failed to load chats:', error);
            this.showError(error.message);
        }
    }

    filterChats() {
        // Debug: log filter info
        if (this.currentFilter === 'cursor-agent') {
            console.log('Filtering for cursor-agent. Total chats:', this.chats.length);
            console.log('Cursor-agent chats:', this.chats.filter(c => c.isCursorAgent).length);
            console.log('Sample chat:', this.chats[0] ? {
                id: this.chats[0].id,
                format: this.chats[0].format,
                isCursorAgent: this.chats[0].isCursorAgent
            } : 'no chats');
        }
        
        this.filteredChats = this.chats.filter(chat => {
            // Apply location filter
            if (this.currentFilter === 'local' && chat.location !== ChatLocation.LOCAL) {
                return false;
            }
            if (this.currentFilter === 'remote' && chat.location !== ChatLocation.REMOTE) {
                return false;
            }
            
            // Apply format filter
            if (this.currentFilter === 'cursor-agent' && !chat.isCursorAgent) {
                return false;
            }
            
            // Apply status filter
            if (this.currentFilter === 'active' && chat.status !== 'active') {
                return false;
            }
            if (this.currentFilter === 'archived' && chat.status !== 'archived') {
                return false;
            }

            // Apply search
            if (this.searchQuery) {
                const searchLower = this.searchQuery;
                const matchesTitle = chat.title.toLowerCase().includes(searchLower);
                const matchesPreview = chat.preview.toLowerCase().includes(searchLower);
                const matchesDevice = chat.remoteInfo 
                    ? chat.remoteInfo.deviceName.toLowerCase().includes(searchLower)
                    : false;
                return matchesTitle || matchesPreview || matchesDevice;
            }

            return true;
        });

        this.renderChats();
    }

    renderChats() {
        // Hide all states
        this.loadingStateEl.classList.add('hidden');
        this.emptyStateEl.classList.add('hidden');
        this.errorStateEl.classList.add('hidden');

        // Clear existing chat cards (but keep state elements)
        const existingCards = this.chatListEl.querySelectorAll('.chat-card');
        existingCards.forEach(card => card.remove());

        if (this.filteredChats.length === 0) {
            this.showEmpty();
            return;
        }

        // Render chat cards
        this.filteredChats.forEach(chat => {
            const card = createChatCard(chat);
            this.chatListEl.appendChild(card);
        });
    }

    showLoading() {
        this.loadingStateEl.classList.remove('hidden');
        this.emptyStateEl.classList.add('hidden');
        this.errorStateEl.classList.add('hidden');
        
        // Remove existing chat cards
        const existingCards = this.chatListEl.querySelectorAll('.chat-card');
        existingCards.forEach(card => card.remove());
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
}

// Initialize the page
document.addEventListener('DOMContentLoaded', () => {
    new ChatListPage();
});

