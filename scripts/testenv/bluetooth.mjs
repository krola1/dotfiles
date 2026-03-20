import { execSync } from 'child_process'

const output = execSync('bluetoothctl devices').toString()
console.log(output)
