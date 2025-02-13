const glob = require('glob').sync
const path = require('path')
const rails = require('esbuild-rails')

require("esbuild").build({
  entryPoints: glob("./app/javascript/**/*.js"),
  bundle: true,
  sourcemap: false,
  outdir: path.join(process.cwd(), "app/assets/builds"),
  watch: process.argv.includes("--watch"),
  plugins: [rails()],
}).catch(() => process.exit(1))