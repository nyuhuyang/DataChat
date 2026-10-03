test_that("clearing every checkbox clears the analysis selection", {
  skip_if_not(file.exists(file.path(project_root, "data", "input", "SPOKE_subset_node.csv")), "checkout-only assets")
  withr::local_options(datachat.app_root = project_root)
  testServer(start_datachat_server, {
    session$setInputs(input_files_list = file.path(project_root, "data", "input", "SPOKE_subset_node.csv"))
    expect_length(artifacts$selected_files, 1)
    session$setInputs(input_files_list = NULL)
    expect_length(artifacts$selected_files, 0)

    foreign <- withr::local_tempfile(fileext = ".csv")
    writeLines("a,b\n1,2", foreign)
    session$setInputs(input_files_list = foreign)
    expect_length(artifacts$selected_files, 0)
  })
})
