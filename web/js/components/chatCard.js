import { Formatter } from '../utils/formatter.js';
import { ChatLocation } from '../models/device.js';

export function createChatCard(chat) {
    const card = document.createElement('div');
    card.className = 'chat-card';
    if (chat.isRemote) {
        card.classList.add('remote-chat-card');
    }
    
    card.addEventListener('click', () => {
        window.location.href = `chat.html?id=${chat.id}`;
    });

    const statusClass = chat.status === 'active' ? 'badge-active' : 'badge-archived';
    const statusText = chat.status.charAt(0).toUpperCase() + chat.status.slice(1);

    // Build remote info HTML if chat is remote
    let remoteInfoHtml = '';
    if (chat.isRemote && chat.remoteInfo) {
        remoteInfoHtml = `
            <div class="chat-card-remote-info">
                <span class="badge badge-remote">
                    📡 ${escapeHtml(chat.remoteInfo.deviceName)}
                </span>
                <span class="device-status-indicator" data-status="${chat.remoteInfo.deviceStatus}">
                    ${chat.remoteInfo.statusIcon} ${chat.remoteInfo.deviceStatus}
                </span>
            </div>
        `;
    }

    card.innerHTML = `
        <div class="chat-card-header">
            <div>
                ${remoteInfoHtml}
                <div class="chat-card-title">${escapeHtml(chat.title)}</div>
                <div class="chat-card-meta">
                    <span>${Formatter.formatTime(chat.lastMessageAt)}</span>
                    <span class="badge ${statusClass}">${statusText}</span>
                </div>
            </div>
        </div>
        <div class="chat-card-preview">
            ${escapeHtml(Formatter.truncate(chat.preview, 150))}
        </div>
        <div class="chat-card-stats">
            <div class="stat">
                <span>💬</span>
                <span>${chat.messageCount} ${Formatter.pluralize(chat.messageCount, 'message')}</span>
            </div>
            ${chat.isRemote && chat.remoteInfo ? `
                <div class="stat">
                    <span>📁</span>
                    <span title="${escapeHtml(chat.remoteInfo.workingDirectory)}">
                        ${escapeHtml(truncatePath(chat.remoteInfo.workingDirectory, 30))}
                    </span>
                </div>
            ` : ''}
            ${chat.totalLinesAdded > 0 || chat.totalLinesRemoved > 0 ? `
                <div class="stat">
                    <span style="color: var(--color-success)">+${chat.totalLinesAdded}</span>
                    <span style="color: var(--color-error)">-${chat.totalLinesRemoved}</span>
                </div>
            ` : ''}
        </div>
    `;

    return card;
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function truncatePath(path, maxLength) {
    if (path.length <= maxLength) return path;
    const parts = path.split('/');
    if (parts.length <= 2) return path;
    return '.../' + parts.slice(-2).join('/');
}

