// API Configuration
export const API_CONFIG = {
    baseUrl: 'http://localhost:8067',
    endpoints: {
        // Local chats
        listChats: '/chats',
        getChatMessages: (chatId) => `/chats/${chatId}`,
        getChatMetadata: (chatId) => `/chats/${chatId}/metadata`,
        createChat: '/agent/create-chat',
        sendMessage: (chatId) => `/chats/${chatId}/agent-prompt`,
        sendMessageAsync: (chatId) => `/chats/${chatId}/agent-prompt-async`,
        getJobStatus: (jobId) => `/jobs/${jobId}/status`,
        getJobDetails: (jobId) => `/jobs/${jobId}`,
        
        // Devices
        listDevices: '/devices',
        getDevice: (deviceId) => `/devices/${deviceId}`,
        createDevice: '/devices',
        updateDevice: (deviceId) => `/devices/${deviceId}`,
        deleteDevice: (deviceId) => `/devices/${deviceId}`,
        testDevice: (deviceId) => `/devices/${deviceId}/test`,
        
        // Remote chats
        listRemoteChats: '/devices/chats/remote',
        createRemoteChat: (deviceId) => `/devices/${deviceId}/create-chat`,
        sendRemoteMessage: (chatId) => `/devices/chats/${chatId}/send-prompt`,
    }
};
