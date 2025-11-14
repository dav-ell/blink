export function createThinkingBox(content) {
    const box = document.createElement('div');
    box.className = 'thinking-box';
    
    box.innerHTML = `
        <div class="thinking-header">
            <span class="thinking-title">💭 Thinking</span>
        </div>
        <div class="thinking-content">
            ${escapeHtml(content)}
        </div>
    `;
    
    return box;
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

