game 'rdr3'
fx_version 'adamant'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
lua54 'yes'

description 'w_weathersync'

-- w_lib bootstrap must be the first shared script
shared_scripts {
	'@w_lib/init.lua',
	'config.lua',
}

-- load the ar/en dictionary at start (language comes from the library)
w_lib { 'locale' }

client_scripts { 'client/*.lua' }
server_scripts { 'server/*.lua' }

files { 'locales/*.json' }

dependency 'w_lib'
-- w_core: its core object is fetched at load (commands, player loaded event)
dependency 'w_core'
