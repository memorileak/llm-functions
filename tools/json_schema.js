const fs = require("node:fs");
const toJsonSchema = require("to-json-schema");

/**
 * Generate the JSON schema of the given JSON data.
 * @typedef {Object} Args
 * @property {string} [json_file] Optional json file path to the json data. If not provided or the file does not exist or is not a file, the tool will get json data from the stdin.
 * @param {Args} args
 */
exports.run = function (args) {
  const { json_file } = args;

  try {
    let text;
    if (
      json_file &&
      fs.existsSync(json_file) &&
      fs.statSync(json_file).isFile()
    ) {
      text = fs.readFileSync(json_file, "utf8");
    } else {
      // Fall back to stdin (fd 0), read synchronously
      text = fs.readFileSync(0, "utf8");
    }
    const json_object = JSON.parse(text);
    const json_schema = toJsonSchema(json_object);
    return JSON.stringify(json_schema, null, 2);
  } catch (error) {
    console.error(error);
    return `Error: ${error.message}`;
  }
};
