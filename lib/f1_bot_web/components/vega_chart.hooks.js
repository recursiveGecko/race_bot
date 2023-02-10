import vegaEmbed from 'vega-embed';
import * as vegaLite from 'vega-lite';
import * as vega from 'vega';

export default {
  mounted() {
    window.vl = vegaLite;
    console.log("VegaChart mounted")

    // This element is important so we can uniquely identify which element will be loaded
    this.props = { id: this.el.getAttribute("data-id") };

    const opts = {
      renderer: 'svg',
      actions: {
        export: true,
        source: false,
        compiled: false,
        editor: false
      }
    }

    // Handles the event of creating a graph and loads vegaEmbed targetting our main hook element
    this.handleEvent(`vega_chart:${this.props.id}:init`, ({ spec }) => {
      console.log(spec)
      
      vegaEmbed(this.el, spec, opts)
        .then((result) => {
          if (this.view) {
            console.log('Destroying previous instance of vega view');
            this.view.finalize();
          }
          this.view = result.view;
        })
        .catch((error) => console.error(error));
    });

  }
}