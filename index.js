const express = require("express");
const { postgraphile } = require("postgraphile");
const Config = require("good-config");
const jwt = require("jsonwebtoken");

const config = new Config({
  path: "./config",
  format: "yml", // Optional
  provider: "FileSystem"
});

config
  .load()
  .then(() => {
    const configData = config.getAll();

    const app = express();

    app.use(
      postgraphile(configData.db, configData.graphile.schemas, {
        pgDefaultRole: "user_login",
        graphiql: true,
        showErrorStack: true,
        extendedErrors: [
          "severity",
          "code",
          "detail",
          "hint",
          "position",
          "internalPosition",
          "internalQuery",
          "where",
          "schema",
          "table",
          "column",
          "dataType",
          "constraint",
          "file",
          "line",
          "routine"
        ],
        jwtSecret: configData.auth.secret,
        jwtVerifyOptions: {
          audience: null
        }
      })
    );
    app.listen(configData.app.port);

    app.get("/login", (req, res, next) => {
      res.json({
        1: jwt.sign(
          { role: "user_login", user_id: 1 },
          configData.auth.secret,
          {}
        ),
        2: jwt.sign(
          { role: "user_login", user_id: 2 },
          configData.auth.secret,
          {}
        ),
        3: jwt.sign(
          { role: "user_login", user_id: 3 },
          configData.auth.secret,
          {}
        ),
        admin: jwt.sign(
          { role: "user_admin", user_id: 0 },
          configData.auth.secret,
          {}
        )
      });
    });

    console.log(`App is running on ${configData.app.port}`);
  })
  .catch(err => {
    console.log(err);
    process.exit(1);
  });
