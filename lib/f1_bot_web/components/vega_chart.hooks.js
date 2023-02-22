import vegaEmbed from 'vega-embed';
// Hacky import for the sake of getting type annotations
import * as vegaEmbedPkg from 'vega-embed';

export default {
  /** @type {?vegaEmbedPkg.Result} */
  embed: null,

  mounted() {
    console.log("VegaChart mounted");

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

    // Handles the event of creating a graph, cleanup, and creates vegaEmbed targetting our main hook element
    this.handleEvent(`vega_chart:${this.props.id}:init`, async ({ spec }) => {
      console.log(`${this.props.id} Received init event:`, spec)

      try {
        if (this.embed) {
          console.log('Destroying previous instance of Vega view');
          this.embed.finalize();
        }

        this.embed = await vegaEmbed(this.el, spec, opts);
      } catch (e) {
        console.error(e)
      }
    });

    // Handles streaming data into the chart, replacing the entire dataset or inserting new data
    this.handleEvent(`vega_chart:${this.props.id}:data`, async ({ dataset, op, data }) => {
      console.log(`${this.props.id} Received data event:`, dataset, op, data)

      if (!dataset) {
        console.warn('Dataset name not provided, skipping')
        return;
      }

      let changeSet = null;

      if (op === 'replace') {
        changeSet = this.embed.view.changeset().remove().insert(data);
      } else if (op === 'insert') {
        changeSet = this.embed.view.changeset().insert(data);
      } else {
        console.warn('Invalid operation, skipping')
        return;
      }

      this.embed.view.change(dataset, changeSet).run();
    });
  }
}