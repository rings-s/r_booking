# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Chartkick and Chart.js - Rails 8 recommended setup
pin "chartkick", to: "https://cdn.jsdelivr.net/npm/chartkick@5/dist/chartkick.js"
pin "Chart.bundle", to: "https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.js"
# Time scale adapter for Chart.js (required for date/time series)
pin "chartjs-adapter-date-fns", to: "https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns@3/dist/chartjs-adapter-date-fns.bundle.min.js"
