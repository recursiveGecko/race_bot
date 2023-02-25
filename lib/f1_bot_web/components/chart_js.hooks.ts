import { ChartVisualization, createChart } from '@assets/Visualizations';

export default {
  mounted() {
    this.props = { id: this.el.id }
    console.log("Chart.js mounted", this.el);

    this.handleEvent(`chartjs:${this.props.id}:init`, async ({ chart_class }) => {
      console.log(`${this.props.id} Received init event:`, chart_class)

      const existing = this.props.chart as ChartVisualization;

      if (existing) {
        console.log('Destroying previous Chart.js instance');
        existing.destroy();
      }

      this.props.chart = createChart(chart_class, this.el);
    });

    // Handles streaming data into the chart, replacing the entire dataset or inserting new data
    this.handleEvent(`chartjs:${this.props.id}:data`, async (updatePayload) => {
      console.log(`${this.props.id} Received data event:`, updatePayload)

      const chart = this.props.chart as ChartVisualization;

      if (!chart) {
        console.warn('Chart not initialized, skipping', this.props)
        return;
      }

      chart.updateData(updatePayload);
    });
  }
}
