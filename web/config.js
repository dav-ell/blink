// API Configuration
export const API_CONFIG = {
    baseUrl: 'http://localhost:8067',
    endpoints: {
        listChats: '/chats',
        listCursorAgentChats: '/chats/cursor-agent',
        getChatMessages: (chatId) => `/chats/${chatId}`,
        getChatMetadata: (chatId) => `/chats/${chatId}/metadata`,
        sendMessage: (chatId) => `/chats/${chatId}/agent-prompt`,
        sendMessageAsync: (chatId) => `/chats/${chatId}/agent-prompt-async`,
        getJobStatus: (jobId) => `/jobs/${jobId}/status`,
        getJobDetails: (jobId) => `/jobs/${jobId}`,
        listDevices: '/devices',
        getDevice: (deviceId) => `/devices/${deviceId}`,
        listRemoteChats: '/remote-chats',
        sendRemoteMessage: (chatId) => `/chats/${chatId}/agent-prompt`,
        createRemoteChat: (deviceId) => `/devices/${deviceId}/create-chat`,
        createChat: '/agent/create-chat',
    }
};

