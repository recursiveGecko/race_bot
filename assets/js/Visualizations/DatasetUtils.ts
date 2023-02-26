const DataSetUtils = {
  /**
   * Merges two datasets together, removing points that are no longer in the new dataset and adding points that are new.
   * The reason this is necessary is because Chart.js would animate the entire dataset rather than the last added point
   * if we just replaced it with a new one.
   * 
   * @param existingData Dataset to modify
   * @param newData New dataset to merge into existingData
   * @param keyFn Function that maps a point in the dataset to its unique identifier (e.g. X axis value)
   */
  mergeDataset<T extends {}>(existingData: T[], newData: T[], keyFn: (point: T) => number) {
    const existingKeys = new Set(existingData.map(keyFn));
    const newKeys = new Set(newData.map(keyFn));
    const keysToRemove = new Set([...existingKeys].filter(x => !newKeys.has(x)));
    const keysToAdd = new Set([...newKeys].filter(x => !existingKeys.has(x)));

    const keysToUpdate = new Set([...existingKeys].filter(x => newKeys.has(x)));

    for (let point of existingData) {
      const pointKey = keyFn(point);

      if (keysToRemove.has(pointKey)) {
        existingData.splice(existingData.indexOf(point), 1);
      }

      if (keysToUpdate.has(pointKey)) {
        const newPoint = newData.find(x => keyFn(x) === pointKey);
        Object.assign(point, newPoint);
      }
    }

    for (let point of newData) {
      if (!keysToAdd.has(keyFn(point))) continue;

      // Assumes existingData is sorted by keyFn in ascending order
      const insertIndex = existingData.findIndex(x => keyFn(x) > keyFn(point));

      if(insertIndex === -1) {
        existingData.push(point);
      } else {
        // Data must be inserted in the correct location for lines to be drawn correctly
        existingData.splice(insertIndex, 0, point);
      }
    }
  }
}

export { DataSetUtils };