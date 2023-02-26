import { Storage } from "@assets/Storage";

const HighlightOnChange = {
  mounted() {
    this.lastVal = this.el.innerText;
  },

  updated() {
    const animationClass = 'data-update-highlight';

    const add = () => this.el.classList.add(animationClass);
    const remove = () => this.el.classList.remove(animationClass);

    // Sometimes an update is triggered even though the content hasn't changed.
    if (this.el.innerText === this.lastVal) return;
    this.lastVal = this.el.innerText;

    if (this.timeout) {
      clearTimeout(this.timeout);
      remove();
    }

    this.timeout = setTimeout(() => {
      remove();
    }, 2000);

    add();
  }
};

const SaveParams = {
  mounted() {
    this.handleEvent('save-params', (newParams) => {
      let params;

      try {
        params = Storage.load('params', {}, JSON.parse)
      } catch (e) {
        params = {};
        console.error('Failed to load params from localStorage', e);
      }

      Object.assign(params, newParams);
      Storage.save('params', params);
    })
  }
}

export { HighlightOnChange, SaveParams };
