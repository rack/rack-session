# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

TEST_PATTERN = "sus/**/*.rb"

def test_paths
  return Dir.glob(TEST_PATTERN, base: @root)
end
