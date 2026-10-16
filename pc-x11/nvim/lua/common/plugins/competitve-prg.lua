-- https://github.com/xeluxee/competitest.nvim#receive-testcases-problems-and-contests
if true then return {} end
return {
	'xeluxee/competitest.nvim',
	dependencies = 'MunifTanjim/nui.nvim',
	config = function()
		require('competitest').setup({
			runner_ui = {
				interface = "split",
			},
		})
	end,

}
