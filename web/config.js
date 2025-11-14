// API Configuration
export const API_CONFIG = {
    baseUrl: 'http://localhost:8067',
    endpoints: {
        listChats: '/chats',
        getChatMessages: (chatId) => `/chats/${chatId}`,
        getChatMetadata: (chatId) => `/chats/${chatId}/metadata`,
        sendMessage: (chatId) => `/chats/${chatId}/agent-prompt`,
        sendMessageAsync: (chatId) => `/chats/${chatId}/agent-prompt-async`,
        getJobStatus: (jobId) => `/jobs/${jobId}/status`,
        getJobDetails: (jobId) => `/jobs/${jobId}`,
    }
};

