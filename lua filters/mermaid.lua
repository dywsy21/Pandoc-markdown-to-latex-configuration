-- Mermaid filter with caption support, git integration, and command availability check

-- Check if mmdc command is available
local function is_mmdc_available()
    -- Fix PowerShell command execution issue
    local handle = io.popen("where.exe mmdc 2> NUL || echo not found")
    if not handle then return false end
    
    local result = handle:read("*a")
    handle:close()
    
    -- If 'where' command returns a path (and not "not found"), mmdc is available
    return not result:match("not found")
end

-- Global flag to track if mmdc is available (checked only once)
local mmdc_available = nil

local output_dir = "mermaid-images"

-- Function to create a unique filename based on content
local function get_filename(code)
    local hash = ""
    for i = 1, math.min(#code, 10) do
        hash = hash .. string.format("%02x", string.byte(code, i))
    end
    return "mermaid-" .. hash .. ".png"
end

local function ensure_directory_exists(dir)
    os.execute('if not exist "' .. dir .. '" mkdir "' .. dir .. '"')
end

-- Extract caption from code
local function extract_caption(code)
    -- Look for special comment: %% caption: Your caption text
    local caption_line = code:match("^%s*%%%% caption:%s*(.-)%s*\n")
    if caption_line and caption_line ~= "" then
        return caption_line
    end
    
    -- Default caption
    return "Mermaid diagram"
end

-- Check if we are in a git repository
local function is_git_repo()
    local cmd = 'git rev-parse --is-inside-work-tree 2>nul'
    local handle = io.popen(cmd)
    if not handle then return false end
    
    local result = handle:read("*a")
    handle:close()
    
    return result:match("true") ~= nil
end

-- Check if pattern exists in gitignore
local function pattern_in_gitignore(gitignore_path, pattern)
    local f = io.open(gitignore_path, "r")
    if not f then return false end
    
    for line in f:lines() do
        -- Trim whitespace and check exact match
        line = line:gsub("^%s*(.-)%s*$", "%1")
        if line == pattern then
            f:close()
            return true
        end
    end
    
    f:close()
    return false
end

-- Update gitignore file
local function update_gitignore()
    if not is_git_repo() then
        io.stderr:write("Not a git repository, skipping .gitignore update\n")
        return
    end
    
    -- Find root of git repo
    local cmd = 'git rev-parse --show-toplevel'
    local handle = io.popen(cmd)
    if not handle then return end
    
    local repo_root = handle:read("*l")
    handle:close()
    
    if not repo_root then return end
    
    local gitignore_path = repo_root .. "\\.gitignore"
    local pattern = "**/mermaid-images"
    
    -- Check if .gitignore exists and if pattern is already there
    if pattern_in_gitignore(gitignore_path, pattern) then
        io.stderr:write("Pattern already in .gitignore\n")
        return
    end
    
    -- Append or create .gitignore
    local exists = io.open(gitignore_path, "r") ~= nil
    
    local f = io.open(gitignore_path, "a")
    if f then
        if exists then
            f:write("\n" .. pattern .. "\n")
        else
            f:write(pattern .. "\n")
        end
        f:close()
        io.stderr:write("Added mermaid-images to .gitignore\n")
    end
end

function CodeBlock(block)
    -- Check if this is a mermaid code block
    io.stderr:write("Checking block...\n")
    if block.classes and block.classes[1] == "mermaid" then
        -- Check mmdc availability (only once)
        if mmdc_available == nil then
            mmdc_available = is_mmdc_available()
            
            if not mmdc_available then
                io.stderr:write("\n⚠️ ERROR: 'mmdc' command not found. Mermaid diagrams will not be processed.\n")
                io.stderr:write("Please install mermaid-cli by running: npm install -g @mermaid-js/mermaid-cli\n\n")
                -- Return original block to keep mermaid source in document
                return block
            end
        elseif mmdc_available == false then
            -- Already checked and not available
            return block
        end
        
        ensure_directory_exists(output_dir)
        
        -- Extract caption
        local caption_text = extract_caption(block.text)
        
        -- Remove caption line from the mermaid code
        local mermaid_code = block.text:gsub("^%s*%%%% caption:%s*.-\n", "")
        
        local image_file = get_filename(mermaid_code)
        -- Use consistent forward slash path for both file operations and references
        local image_path = output_dir .. "/" .. image_file
        -- Fix windows path for OS execution
        local os_image_path = output_dir .. "\\" .. image_file
        
        local tmp_file = os.getenv("TEMP") .. "\\mermaid-temp-" .. os.time() .. ".mmd"
        
        local f = io.open(tmp_file, "w")
        if not f then
            io.stderr:write("Error: Cannot create temporary file\n")
            return block
        end
        
        f:write(mermaid_code)
        f:close()
        
        -- Universal parameters for all diagram types
        local command = string.format('mmdc -i "%s" -o "%s" --backgroundColor white', 
                                    tmp_file, os_image_path)
        -- print the command
        io.stderr:write("Running: " .. command .. "\n")
        local success = os.execute(command)
        
        -- Clean up temp file right after use
        os.remove(tmp_file)
        
        if success then
            local caption = {pandoc.Str(caption_text)}
            -- Use the same path format that was used to create the image
            local src = image_path
            local attr = pandoc.Attr("", {"mermaid-diagram"}, {})
            return pandoc.Para{pandoc.Image(caption, src, "", attr)}
        else
            io.stderr:write("Warning: Failed to render mermaid diagram\n")
            return block
        end
    end
    
    return block
end

-- Handle operations at the end of processing
function Pandoc(doc)
    -- Only update gitignore if we're actually processing Mermaid diagrams
    if mmdc_available then
        update_gitignore()
    end
    return doc
end

return {
    { CodeBlock = CodeBlock },
    { Pandoc = Pandoc }
}
