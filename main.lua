-- office.yazi plugin with comprehensive cross-platform fixes.
-- This version builds upon previous community efforts (like PR #14) to provide a fully functional experience on Windows.
--
-- What this version adds or improves compared to PR #14:
-- 1.  **True Temporary Directory Handling**: Fixes the hardcoded "/tmp/" path, which was the primary reason previews still failed on Windows after initial fixes. This version uses Yazi's own cache directory, a robust and platform-agnostic approach.
-- 2.  **Handles File Paths with Spaces**: A critical fix for real-world usage on all platforms. Arguments are now passed individually to the command builder to correctly handle filenames containing spaces.
-- 3.  **Robust Success Detection**: We no longer rely on LibreOffice's potentially misleading exit code. Instead, success is determined by the actual creation of the PDF file, resolving issues where previews worked but logs showed errors.
-- 4.  **Refined Platform-Specific Logic**: Improved logic for finding executables and getting environment variables for maximum reliability.

local M = {}

-- Function to get a sanitized username for creating unique temporary directories.
-- PR #14 correctly identified the need to replace `ya.uid()`.
-- OUR IMPROVEMENT: We check for "USERNAME" first, which is the standard on Windows, making it more robust.
local function get_safe_username()
	local username = os.getenv("USERNAME") or os.getenv("USER") or os.getenv("LOGNAME")
	if not username then
		return "yazi_fallback_user"
	end
	return username:gsub("[\\/<>:\"|?*%s]", "_"):lower()
end

-- Function to find the correct command for LibreOffice ('libreoffice' or 'soffice').
-- PR #14 correctly identified the need for this dynamic check.
-- OUR IMPROVEMENT: We use platform-specific commands ('where' for Windows, 'which' for Unix) for the check, which is more reliable than just trying to execute the command.
local function get_libreoffice_command()
	local names = { "libreoffice", "soffice" }
	local is_windows = ya.target_os() == "windows"
	local CHECK_CMD = is_windows and "where" or "which"
	local REDIRECTION = is_windows and " >nul 2>&1" or " >/dev/null 2>&1"

	for _, name in ipairs(names) do
		if os.execute(CHECK_CMD .. " " .. name .. REDIRECTION) then
			return name
		end
	end

	ya.notify({
		title = "office.yazi",
		content = "Could not find `libreoffice` or `soffice` in your system's PATH.",
		timeout = 5,
		level = "error",
	})
	return nil
end

-- Initialize global constants for the plugin.
local LIBREOFFICE_COMMAND = get_libreoffice_command()

function M:peek(job)
	local start, cache = os.clock(), ya.file_cache(job)
	if not cache then
		return
	end

	local ok, err = self:preload(job)
	if not ok or err then
		ya.err("office.yazi error: " .. tostring(err))
		return
	end

	ya.sleep(math.max(0, rt.preview.image_delay / 1000 + start - os.clock()))
	ya.image_show(cache, job.area)
	ya.preview_widgets(job, {})
end

function M:seek(job)
	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		local step = ya.clamp(-1, job.units, 1)
		ya.manager_emit("peek", { math.max(0, cx.active.preview.skip + step), only_if = job.file.url })
	end
end

function M:doc2pdf(job)
	local cache_url = ya.file_cache(job)
	if not cache_url then
		return nil, Err("Could not get cache file path from Yazi.")
	end

	-- OUR KEY FIX #1: Use Yazi's cache directory instead of a hardcoded "/tmp/".
	-- The previous PR fixed `ya.uid()` but missed that the temporary directory path itself was Unix-specific,
	-- which was the main reason previews still failed on Windows.
	local temp_dir_url = cache_url.parent
	if not temp_dir_url then
		return nil, Err("Could not determine parent directory of cache file.")
	end

	local temp_dir_path = tostring(temp_dir_url)
	local source_file_path = tostring(job.file.url)

	-- OUR KEY FIX #2: Handle file paths with spaces.
	-- We pass each argument individually to the Command builder. This is a critical fix for real-world
	-- filenames and was not addressed in the previous PR.
	local libreoffice = Command(LIBREOFFICE_COMMAND)
		:arg("--headless")
		:arg("--convert-to")
		:arg("pdf")
		:arg("--outdir")
		:arg(temp_dir_path)
		:arg(source_file_path)
		:stdin(Command.NULL)
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()

	local pdf_filename = job.file.url.stem .. ".pdf"
	local tmp_pdf_url = temp_dir_url:join(pdf_filename)
	local tmp_pdf_path = tostring(tmp_pdf_url)

	-- OUR KEY FIX #3: Robust success detection.
	-- We define success by the existence of the output file, not by the command's exit code,
	-- which can be misleadingly non-zero even on success. This makes the plugin's error logging accurate.
	if not fs.cha(tmp_pdf_url) then
		local output = libreoffice.stdout .. libreoffice.stderr
		return nil, Err("LibreOffice ran but the PDF file was not created. Output: %s", output)
	end

	return tmp_pdf_path
end

function M:preload(job)
	local cache = ya.file_cache(job)
	if not cache or fs.cha(cache) then
		return true
	end

	local tmp_pdf_path, err = self:doc2pdf(job)
	if not tmp_pdf_path then
		return false, err
	end

	-- Also apply the individual argument fix to pdftoppm for consistency and robustness.
	local output, err = Command("pdftoppm")
		:arg("-singlefile")
		:arg("-jpeg")
		:arg("-jpegopt")
		:arg("quality=" .. rt.preview.image_quality)
		:arg(tmp_pdf_path)
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:output()

	fs.remove("file", Url(tmp_pdf_path))

	if not output then
		return false, Err("Failed to start `pdftoppm`: %s", err)
	elseif not output.status.success then
		return false, Err("`pdftoppm` failed: %s", output.stderr)
	end

	local ok, err = fs.write(cache, output.stdout)
	if not ok then
		return false, Err("Failed to write to cache file: %s", err)
	end

	return true
end

return M
