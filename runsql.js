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

  try {
    const sqlFindUser = sql("./db.sql");
    await db.any(sqlFindUser);
    console.log("All done! gg ez!");
  } catch (err) {
    console.error("An error occurred:", err);
    process.exitCode = 1;
  } finally {
    pgp.end();
  }
}

async function main() {
  await config.load();
  const configData = config.getAll();
  await seedMe(configData.db);
}

main().catch(err => {
  console.log(err);
  process.exit(1);
});
