local helpers = require('test.helpers')

describe("Neovim -> Aider (/add)", function()
  it("sends /add command when a buffer is opened", function()
    local test_file = "test_file_auto_add.txt"
    vim.fn.writefile({ "test" }, test_file)

    -- Open the file
    vim.cmd("edit " .. test_file)

    -- Verify /add was sent to Aider
    local expected_cmd = "/add " .. vim.fn.fnamemodify(test_file, ":p")
    helpers.assert_aider_received(expected_cmd)

    -- Cleanup
    vim.fn.delete(test_file)
  end)
end)
