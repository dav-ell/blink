import { API_CONFIG } from '../config.js';

class ApiClient {
    constructor() {
        this.baseUrl = API_CONFIG.baseUrl;
    }

    async request(endpoint, options = {}) {
        const url = `${this.baseUrl}${endpoint}`;
        const method = options.method || 'GET';
        const defaultOptions = {
            headers: {
                'Content-Type': 'application/json',
            },
        };

        // Log outgoing request
        console.log('[API] Request:', {
            method: method,
            url: url,
            body: options.body ? JSON.parse(options.body) : undefined,
            timestamp: new Date().toISOString()
        });

        try {
            const response = await fetch(url, { ...defaultOptions, ...options });
            
            if (!response.ok) {
                const errorData = await response.json().catch(() => ({}));
                throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
            }

            const data = await response.json();
            
            // Log successful response
            console.log('[API] Response:', {
                status: response.status,
                url: url,
                messageCount: data.messages?.length || data.chats?.length || 0,
                hasMetadata: !!data.metadata,
                dataKeys: Object.keys(data),
                timestamp: new Date().toISOString()
            });

            return data;
        } catch (error) {
            // Log error with full context
            console.error('[API] Request failed:', {
                method: method,
                url: url,
                error: error.message,
                stack: error.stack
            });
            throw error;
        }
    }

    async listChats(params = {}) {
        const queryParams = new URLSearchParams({
            include_archived: params.includeArchived || false,
            sort_by: params.sortBy || 'last_updated',
            offset: params.offset || 0,
            ...(params.limit && { limit: params.limit }),
        });

        return this.request(`${API_CONFIG.endpoints.listChats}?${queryParams}`);
    }

    async listCursorAgentChats(params = {}) {
        const queryParams = new URLSearchParams({
            include_archived: params.includeArchived || false,
            sort_by: params.sortBy || 'last_updated',
            offset: params.offset || 0,
            ...(params.limit && { limit: params.limit }),
        });

        return this.request(`${API_CONFIG.endpoints.listCursorAgentChats}?${queryParams}`);
    }

    async getChatMessages(chatId, params = {}) {
        const queryParams = new URLSearchParams({
            include_metadata: params.includeMetadata !== undefined ? params.includeMetadata : true,
            include_content: params.includeContent !== undefined ? params.includeContent : true,
            ...(params.limit && { limit: params.limit }),
        });

        return this.request(`${API_CONFIG.endpoints.getChatMessages(chatId)}?${queryParams}`);
    }

    async getChatMetadata(chatId) {
        return this.request(API_CONFIG.endpoints.getChatMetadata(chatId));
    }

    async sendMessage(chatId, message, async = false) {
        const endpoint = async 
            ? API_CONFIG.endpoints.sendMessageAsync(chatId)
            : API_CONFIG.endpoints.sendMessage(chatId);

        return this.request(endpoint, {
            method: 'POST',
            body: JSON.stringify({ prompt: message }),
        });
    }

    async getJobStatus(jobId) {
        return this.request(API_CONFIG.endpoints.getJobStatus(jobId));
    }

    async getJobDetails(jobId) {
        return this.request(API_CONFIG.endpoints.getJobDetails(jobId));
    }

    // Device endpoints
    async listDevices(params = {}) {
        const queryParams = new URLSearchParams({
            include_inactive: params.includeInactive || false,
        });

        return this.request(`${API_CONFIG.endpoints.listDevices}?${queryParams}`);
    }

    async getDevice(deviceId) {
        return this.request(API_CONFIG.endpoints.getDevice(deviceId));
    }

    // Remote chat endpoints
    async listRemoteChats(deviceId = null) {
        const queryParams = new URLSearchParams();
        if (deviceId) {
            queryParams.append('device_id', deviceId);
        }

        return this.request(`${API_CONFIG.endpoints.listRemoteChats}?${queryParams}`);
    }

    async sendRemoteMessage(chatId, message) {
        return this.request(API_CONFIG.endpoints.sendRemoteMessage(chatId), {
            method: 'POST',
            body: JSON.stringify({ prompt: message }),
        });
    }

    async createRemoteChat(deviceId, workingDirectory, name = null) {
        return this.request(API_CONFIG.endpoints.createRemoteChat(deviceId), {
            method: 'POST',
            body: JSON.stringify({
                device_id: deviceId,
                working_directory: workingDirectory,
                ...(name && { name }),
            }),
        });
    }

    async createLocalChat(name = null) {
        return this.request(API_CONFIG.endpoints.createChat, {
            method: 'POST',
            body: JSON.stringify({
                ...(name && { name }),
            }),
        });
    }
}

export const apiClient = new ApiClient();

