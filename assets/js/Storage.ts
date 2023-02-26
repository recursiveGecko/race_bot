export const Storage = {
  save<T extends {}>(key: string, value: string | number | T) {
    let saveValue: string;

    switch (typeof value) {
      case 'object':
        saveValue = JSON.stringify(value);
        break;
      case "number":
        saveValue = value.toString();
        break;
      case 'string':
        saveValue = value;
        break;
      default:
        console.warn('Ignoring LocalStorage save request for value of type', typeof value, value)
        return;
    }

    window.localStorage.setItem(key, saveValue);
  },

  load<T>(key: string, defaultVal: T, parseFn?: (x: string) => T) {
    const loaded = window.localStorage.getItem(key);

    if (loaded && parseFn) {
      return parseFn(loaded)
    } else if (loaded) {
      return loaded;
    } else {
      return defaultVal;
    }
  }
}