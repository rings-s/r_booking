// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

console.log('=== DEBUG: Loading Stimulus controllers...')
eagerLoadControllersFrom("controllers", application)
console.log('=== DEBUG: Controllers loaded')
