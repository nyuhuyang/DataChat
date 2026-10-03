test_that("unique_upload_name strips directories and avoids collisions", {
  expect_equal(unique_upload_name("../../etc/passwd.csv"), "passwd.csv")
  expect_equal(unique_upload_name("a.csv", c("a.csv")), "a_2.csv")
  expect_equal(unique_upload_name("a.csv", c("a.csv", "a_2.csv")), "a_3.csv")
  expect_equal(unique_upload_name("a_2.csv", c("a.csv", "a_2.csv")), "a_2_2.csv")
  expect_equal(unique_upload_name("noext", c("noext")), "noext_2")
  expect_equal(unique_upload_name(".."), "upload")
  expect_equal(unique_upload_name("."), "upload")
  expect_equal(unique_upload_name(""), "upload")
  expect_equal(unique_upload_name("profiles", c("profiles")), "profiles_2")
  long <- unique_upload_name(paste0(strrep("a", 246), ".csv"))
  expect_equal(long, paste0(strrep("a", 100), ".csv"))
})

test_that("load_dotenv splits at the first '=' and last assignment wins", {
  root <- withr::local_tempdir()
  writeLines(c(
    "# comment=1",
    "DATACHAT_TEST_A=secret=",
    "DATACHAT_TEST_B=a=b",
    "DATACHAT_TEST_C=first",
    "DATACHAT_TEST_C= "
  ), file.path(root, ".env"))
  withr::local_options(datachat.app_root = root)
  withr::local_envvar(DATACHAT_TEST_A = NA, DATACHAT_TEST_B = NA, DATACHAT_TEST_C = NA)
  capture.output(load_dotenv())
  expect_equal(Sys.getenv("DATACHAT_TEST_A"), "secret=")
  expect_equal(Sys.getenv("DATACHAT_TEST_B"), "a=b")
  expect_equal(Sys.getenv("DATACHAT_TEST_C", "unset"), "")
})

test_that("llm_api_key routes Anthropic and OpenAI-compatible keys separately", {
  withr::local_envvar(DATACHAT_API_KEY = "openai-key", DATACHAT_ANTHROPIC_API_KEY = "")
  expect_equal(llm_api_key("https://api.anthropic.com/v1"), "")
  expect_equal(llm_api_key("https://api.openai.com/v1"), "openai-key")

  withr::local_envvar(DATACHAT_ANTHROPIC_API_KEY = "anthropic-key")
  expect_equal(llm_api_key("https://api.anthropic.com/v1"), "anthropic-key")
})

test_that("get_llm_providers skips providers without a matching key", {
  withr::local_envvar(
    DATACHAT_API_KEY = "openai-key",
    DATACHAT_ANTHROPIC_API_KEY = "",
    DATACHAT_LLM_TestClaude = "https://api.anthropic.com/v1|claude-x",
    DATACHAT_LLM_TestGPT = "https://api.openai.com/v1|gpt-x"
  )
  providers <- suppressMessages(capture.output(p <- get_llm_providers()))
  expect_true("TestGPT" %in% names(p))
  expect_false("TestClaude" %in% names(p))
})

gate_started <- function(env, inputs = list()) {
  started <- FALSE
  withr::local_envvar(env)
  testServer(build_server(start_server = function(...) started <<- TRUE), {
    for (step in inputs) {
      do.call(session$setInputs, step)
    }
  })
  started
}

test_that("password gate starts modules only after the correct password", {
  expect_true(gate_started(c(DATACHAT_APP_PASSWORD = "", R_CONFIG_ACTIVE = "")))
  expect_false(gate_started(c(DATACHAT_APP_PASSWORD = "", R_CONFIG_ACTIVE = "shinyapps")))
  expect_false(gate_started(c(DATACHAT_APP_PASSWORD = "pw", R_CONFIG_ACTIVE = "")))
  expect_false(gate_started(
    c(DATACHAT_APP_PASSWORD = "pw", R_CONFIG_ACTIVE = ""),
    list(list(app_password = "wrong", app_login = 1))
  ))
  expect_true(gate_started(
    c(DATACHAT_APP_PASSWORD = "pw", R_CONFIG_ACTIVE = ""),
    list(list(app_password = "pw", app_login = 1))
  ))
})

test_that("password gate rejects attempts during cooldown", {
  expect_false(gate_started(
    c(DATACHAT_APP_PASSWORD = "pw", R_CONFIG_ACTIVE = ""),
    list(
      list(app_password = "wrong", app_login = 1),
      list(app_password = "pw", app_login = 2)
    )
  ))
})

test_that("deploy whitelist ships app files and demo data only", {
  withr::local_dir(project_root)
  skip_if_not(file.exists("deploy.R") && file.exists(".env"), "checkout-only assets")
  deploy_env <- new.env()
  sys.source("deploy.R", envir = deploy_env)
  files <- deploy_env$deploy_files()

  expect_true(all(c("app.R", ".env", "R/_disable_autoload.R", "R/templates/force_network.R",
                    "data/input/SPOKE_subset_node.csv") %in% files))
  expect_false(any(grepl("SPOKE_edges\\.csv$|^data/output|^ui/|^server/|^tests/|^\\.local|^\\.claude", files)))
  expect_lt(sum(file.size(files)), 10 * 1024^2)

  env_file <- withr::local_tempfile()
  writeLines(c("# DATACHAT_APP_PASSWORD=x", "DATACHAT_APP_PASSWORD=secret"), env_file)
  expect_true(deploy_env$env_has_password(env_file))
  writeLines(c("DATACHAT_APP_PASSWORD=secret", "DATACHAT_APP_PASSWORD=  "), env_file)
  expect_false(deploy_env$env_has_password(env_file))
  writeLines("DATACHAT_APP_PASSWORD=secret=", env_file)
  expect_true(deploy_env$env_has_password(env_file))
  writeLines("OTHER=1", env_file)
  expect_false(deploy_env$env_has_password(env_file))
})

test_that("app.R builds a Shiny app object", {
  withr::local_dir(project_root)
  skip_if_not(file.exists("app.R"), "checkout-only assets")
  withr::local_options(datachat.app_root = NULL)
  app <- suppressMessages(capture.output(obj <- source("app.R", local = new.env())$value))
  expect_s3_class(obj, "shiny.appobj")
})
