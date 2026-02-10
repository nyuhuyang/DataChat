# Quick Test: Verify Preset System Works
# Run this in RStudio console to test the fix

# Source the preset helpers
source("R/presets.R")

# Create sample data
sample_nodes <- data.frame(
  node_id = 1:20,
  name = paste0("Node", 1:20),
  node_type = sample(c("TypeA", "TypeB", "TypeC"), 20, replace = TRUE)
)

sample_edges <- data.frame(
  source = sample(1:20, 30, replace = TRUE),
  target = sample(1:20, 30, replace = TRUE),
  edge_type = sample(c("EdgeX", "EdgeY", "EdgeZ"), 30, replace = TRUE)
)

# Prepare inputs as the app would
datasets <- list(
  nodes_sample = sample_nodes,
  edges_sample = sample_edges
)

selected <- c("nodes_sample", "edges_sample")
params <- list()

# Test 1: Node Type Distribution
cat("\n=== TEST 1: Node Type Distribution ===\n")
template_code <- load_template("node_type_distribution")
if (!is.null(template_code)) {
  result <- execute_template(template_code, datasets, "nodes_sample", params)
  cat("Success:", result$success, "\n")
  cat("Result table rows:", nrow(result$result_table), "\n")
  cat("Has plot:", !is.null(result$result_plot), "\n")
  cat("Logs:\n", result$output, "\n")
} else {
  cat("ERROR: Could not load template\n")
}

# Test 2: Edge Type Count
cat("\n=== TEST 2: Edge Type Count ===\n")
template_code <- load_template("edge_type_count")
if (!is.null(template_code)) {
  result <- execute_template(template_code, datasets, "edges_sample", params)
  cat("Success:", result$success, "\n")
  cat("Result table rows:", nrow(result$result_table), "\n")
  cat("Has plot:", !is.null(result$result_plot), "\n")
} else {
  cat("ERROR: Could not load template\n")
}

# Test 3: Schema Check
cat("\n=== TEST 3: Schema Check ===\n")
template_code <- load_template("schema_check")
if (!is.null(template_code)) {
  result <- execute_template(template_code, datasets, selected, params)
  cat("Success:", result$success, "\n")
  cat("Result table rows:", nrow(result$result_table), "\n")
  cat("Logs:\n", result$output, "\n")
} else {
  cat("ERROR: Could not load template\n")
}

cat("\n=== ALL TESTS COMPLETE ===\n")
