export default {
  mounted() {
    const button = this.el;

    button.addEventListener('click', () => {
      const href = button.getAttribute('data-href');
      const height = button.getAttribute('data-height') || 500;
      const width = button.getAttribute('data-width') || 500;

      if (href) {
        window.open(href, '_blank', `popup,height=${height},width=${width}`)
      }
    });
  }
}