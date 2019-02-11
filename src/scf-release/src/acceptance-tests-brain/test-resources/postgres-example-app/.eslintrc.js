module.exports = {
  root: true,
  parser: 'babel-eslint',
  parserOptions: {
    sourceType: 'module'
  },
  env: {
    node: true
  },
  extends: 'airbnb-base',
  rules: {
    'max-len': ['warn', 100]
  }
};
