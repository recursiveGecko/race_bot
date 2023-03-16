class DarkModeObserver {
  private static el: Element;
  private static observer: MutationObserver;
  private static darkModeEnabled: boolean;

  private static DARK_EL_QUERY = 'html';
  private static DARK_CLASS = 'dark';
  private static EVENT_NAME = 'darkModeChanged';

  static init() {
    if (this.observer != null) {
      throw new Error('DarkModeObserver already initialized');
    }

    const el = document.querySelector(this.DARK_EL_QUERY);
    if (!el) {
      throw new Error(`DarkModeObserver could not find dark mode element with selector: ${this.DARK_EL_QUERY}`);
    }
    this.el = el;

    this.darkModeEnabled = this.checkDarkModeEnabled();

    this.observer = new MutationObserver(this.handleMutation.bind(this));
    this.observer.observe(el, { attributes: true, attributeFilter: ['class'] });

    console.log('DarkModeObserver initialized');
  }

  static subscribe(listener: EventListener) {
    if (!this.el) throw new Error('DarkModeObserver must be initialized first');

    this.el.addEventListener(this.EVENT_NAME, listener);
  }

  static unsubscribe(listener: EventListener) {
    if (!this.el) throw new Error('DarkModeObserver must be initialized first');

    this.el.removeEventListener(this.EVENT_NAME, listener);
  }

  static isDarkModeEnabled() {
    if (!this.el) throw new Error('DarkModeObserver must be initialized first');

    return this.darkModeEnabled;
  }

  private static checkDarkModeEnabled() {
    if (!this.el) throw new Error('DarkModeObserver must be initialized first');

    return this.el.classList.contains(this.DARK_CLASS);
  }

  private static handleMutation(mutations) {
    const wasEnabled = this.darkModeEnabled;
    this.darkModeEnabled = this.checkDarkModeEnabled();

    if (wasEnabled !== this.darkModeEnabled) {
      console.log(`DarkModeObserver: dark mode ${this.darkModeEnabled ? 'enabled' : 'disabled'}`);

      const event = new CustomEvent(this.EVENT_NAME, {
        detail: {
          darkModeEnabled: this.darkModeEnabled
        }
      });

      this.el.dispatchEvent(event)
    }
  }
}

export { DarkModeObserver }