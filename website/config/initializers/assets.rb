# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Location of manifest file.
Rails.application.config.assets.manifest = if Rails.env.production?
                                           Rails.root.join("public/assets/manifest.json")
                                         else
                                           Rails.root.join("tmp/manifest.json")
                                         end

# Add additional assets to the asset load path.
Rails.application.config.assets.paths << Rails.root.join("config")

# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join("node_modules")

# Add iD's dist directory to the asset load path.
Rails.application.config.assets.paths << Rails.root.join("node_modules/@openstreetmap/id/dist")
