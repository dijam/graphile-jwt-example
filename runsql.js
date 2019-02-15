const pgp = require("pg-promise")();
const Config = require("good-config");

const path = require("path");

const config = new Config({
  path: "./config",
  format: "yml",
  provider: "FileSystem"
});

function sql(file) {
  const fullPath = path.join(__dirname, file);
  return new pgp.QueryFile(fullPath, { debug: true });
}

async function seedMe(conf) {
  const db = pgp({
    user: conf.user,
    host: conf.host,
    password: conf.password,
    database: conf.database,
    port: conf.port
  });

  const sqlFindUser = sql("./db.sql");

  db.any(sqlFindUser)
    .then(() => {
      console.log("All done! gg ez!");
      pgp.end();
      process.exit(0);
    })
    .catch(err => {
      pgp.end();
      console.log(err);
      process.exit(1);
    });
}

config
  .load()
  .then(() => {
    const configData = config.getAll();
    seedMe(configData.db);
  })
  .catch(err => {
    console.log(err);
    process.exit(1);
  });
