-- Drop all schemas
DROP SCHEMA IF EXISTS test CASCADE;
DROP SCHEMA IF EXISTS test_private CASCADE;
DROP SCHEMA IF EXISTS test_public CASCADE;

-- Enable crypto for making hash password
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
-- citext is case-insensitive for comparisons, but maintains capitalisation when read
CREATE EXTENSION IF NOT EXISTS citext;

-- Create schemas
CREATE SCHEMA test;
CREATE SCHEMA test_private;
CREATE SCHEMA test_public;

-- extracting user id from jwt setting
CREATE FUNCTION test_public.get_user_id()
RETURNS integer AS $$
  SELECT nullif(current_setting('jwt.claims.user_id', TRUE),'')::integer;
$$ LANGUAGE sql STABLE;


-- Create a base user table
CREATE TABLE test.user (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  family_name VARCHAR(255) NOT NULL
);

-- Create private user info table for password and email
-- `user` and `user_account` have 1 to 1 relation. We have one row for each user in `user_account` table.
CREATE TABLE test_private.user_account (
  user_id integer PRIMARY KEY REFERENCES test.user ON DELETE CASCADE,
  email citext check(length(email) <= 255 and email ~ '[^@]+@[^@]+\.[^@]+'),
  password TEXT,
  UNIQUE(email)
);

-- Create a table that depends on user data
-- `user` and `user_meme` have one to many relation. We can have many memes for each user.
CREATE TABLE test.user_meme (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL DEFAULT test_public.get_user_id() REFERENCES test.user ON DELETE CASCADE,
  meme_url TEXT NOT NULL
);

-- User regisration function that inserts in both user and user_account
CREATE FUNCTION test_public.register(
  first_name text,
  last_name text,
  email citext,
  password text
) returns test.user as $$
declare
  new_user test.user;
begin
  -- first insert in user table
  insert into test.user (name, family_name) values
    (first_name, last_name)
    returning * into new_user;

  -- use the user id from above insert and insert a user's private information to user_account table
  insert into test_private.user_account (user_id, email, password) values
    (new_user.id, email, crypt(password, gen_salt('bf')));

  return new_user;
end;
$$ language plpgsql strict security definer;



-- `postgres` is a user that we login to postgres with (super user)
-- Create Admin role
DROP ROLE IF EXISTS user_admin;
CREATE ROLE user_admin;
GRANT user_admin to postgres;

-- Create user login role
DROP ROLE IF EXISTS user_login;
CREATE ROLE user_login;
GRANT user_login to postgres, user_admin;

-- Create user guest role
DROP ROLE IF EXISTS user_guest;
CREATE ROLE user_guest;
GRANT user_guest to postgres, user_login;


-- Enable row level security for each table
ALTER TABLE test.user enable row level security;
ALTER TABLE test_private.user_account enable row level security;
ALTER TABLE test.user_meme enable row level security;


-- Table grants for RBAC
-- Grant access to schemas for each role
GRANT USAGE ON SCHEMA test to user_login;
GRANT USAGE ON SCHEMA test_private to user_admin;
GRANT USAGE ON SCHEMA test_public to user_guest;

-- Grant access to each table for each role
GRANT SELECT, UPDATE(name, family_name) ON TABLE test.user TO user_login;
GRANT SELECT, DELETE, INSERT(meme_url), UPDATE(meme_url) ON TABLE test.user_meme TO user_login;
GRANT ALL ON TABLE test.user TO user_admin;
GRANT ALL ON TABLE test_private.user_account TO user_admin;
GRANT EXECUTE ON FUNCTION test_public.register(text, text, text, text) to user_guest; -- For function this is sufficient and no need for policy

-- Table policies for RLS
CREATE POLICY select_user ON test.user FOR SELECT TO user_login USING (id = test_public.get_user_id());
CREATE POLICY update_user ON test.user FOR UPDATE TO user_login USING (id = test_public.get_user_id());
CREATE POLICY select_user_meme on test.user_meme for SELECT TO user_login USING (true); -- Give access to all users to read all memes
CREATE POLICY insert_user_meme on test.user_meme for INSERT TO user_login WITH CHECK (user_id = test_public.get_user_id()); -- Give access to every user to insert memes for themselves
CREATE POLICY update_user_meme ON test.user_meme FOR UPDATE TO user_login USING (user_id = test_public.get_user_id());
CREATE POLICY delete_user_meme ON test.user_meme FOR DELETE TO user_login USING (user_id = test_public.get_user_id());
CREATE POLICY select_all_user on test.user for ALL TO user_admin USING (true); -- Give access to all user data to admin

-- Adding user passwords
SELECT test_public.register('Majid', 'Garmaroudi', 'majid.sadeghi@gmail.com', 'supremeleader');
SELECT test_public.register('Paul', 'Rolland', 'paul.rolland@epitech.eu', 'frenchtoast');


-- Adding user's memes
INSERT INTO test.user_meme(user_id, meme_url) VALUES(1, 'http://meme1');
INSERT INTO test.user_meme(user_id, meme_url) VALUES(1, 'http://meme2');
INSERT INTO test.user_meme(user_id, meme_url) VALUES(1, 'http://meme4');
INSERT INTO test.user_meme(user_id, meme_url) VALUES(2, 'http://meme5');
INSERT INTO test.user_meme(user_id, meme_url) VALUES(2, 'http://meme6');
