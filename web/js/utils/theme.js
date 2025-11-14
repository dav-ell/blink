const THEME_KEY = 'blink-theme';
const THEME_DARK = 'dark';
const THEME_LIGHT = 'light';

export class ThemeManager {
    constructor() {
        this.currentTheme = this.loadTheme();
        this.applyTheme(this.currentTheme);
    }

    loadTheme() {
        const savedTheme = localStorage.getItem(THEME_KEY);
        if (savedTheme) return savedTheme;

        // Check system preference
        if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
            return THEME_DARK;
        }
        return THEME_LIGHT;
    }

    applyTheme(theme) {
        document.documentElement.setAttribute('data-theme', theme);
        this.currentTheme = theme;
        localStorage.setItem(THEME_KEY, theme);
    }

    toggle() {
        const newTheme = this.currentTheme === THEME_DARK ? THEME_LIGHT : THEME_DARK;
        this.applyTheme(newTheme);
        return newTheme;
    }

    isDark() {
        return this.currentTheme === THEME_DARK;
    }

    isLight() {
        return this.currentTheme === THEME_LIGHT;
    }
}

export const themeManager = new ThemeManager();

