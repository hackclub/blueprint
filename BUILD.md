# Toby's notes for building this project

## Step 1: Install dependencies

- Ruby: Best way in my opinion is to use [mise](https://mise.jdx.dev/)
- Postgresql: Run with docker

```sh
docker volume create pg_data
docker run -d \
  --name blueprint_pg \
  -e POSTGRES_USER=blueprint \
  -e POSTGRES_PASSWORD=blueprint \
  -e POSTGRES_DB=postgres \
  -p 5432:5432 \
  -v pg_data:/var/lib/postgresql/data \
  postgres:15
```

- Slack app: [https://api.slack.com/apps?new_app=1](https://api.slack.com/apps?new_app=1)