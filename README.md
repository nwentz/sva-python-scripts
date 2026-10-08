This is a custom-built AI-generated bridge that connects OpenCode to VSCode, allowing your AI agent to read and write files directly in VSCode via a MCP server.






INSTALL PREREQUISITES:

Node.js 18+, VSCode, Opencode. Homebrew (Mac Only)




WINDOWS:

TO INSTALL NODE.JS 18+:

winget install OpenJS.NodeJS.LTS



TO INSTALL VSCODE:

winget install Microsoft.VisualStudioCode



TO INSTALL OPENCODE:

npm install -g opencode-ai





MAC:

TO INSTALL HOMEBREW:

 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

TO INSTALL NODE.JS 18+:

 brew install node

TO INSTALL VSCODE:

brew install --cask visual-studio-code

TO INSTALL OPENCODE:

brew install anomalyco/tap/opencode-v2




After installing all the prerequistes on your preferred operating system,


Download the code as a zip file

github.com/nwentz/sva-python-scripts, branch A5—Bridge-a-second-app → Code → Download ZIP.

Next, run the installer





WINDOWS:

powershell -ExecutionPolicy Bypass -File "C:\Tools\vscode-bridge\install.ps1"



MAC:

bash ~/tools/vscode-bridge/install.sh






EXTRACT PATH:

The zip extracts to the folder named sva-python-scripts-A5—Bridge-a-second-app. It needs to be renamed depending on the operating system in order to match the installer's commands



WINDOWS:

C:\Tools\vscode-bridge 




MAC:

~/tools/vscode-bridge




PORT:

extension.js runs the HTTP server: 127.0.0.1:37651 inside of VSCode



MCP:

vscode-bridge-mcp.mjs wraps that HTTP port as vscode_* tools.



I asked my agent to "Build a bridge to VSCode that will allow you to read and write files in VSCode". It troubleshooted issues with the bridge involving extension not loading, untrusted workspace in VSCode not being supported, and the CLI not expanding, all of which it fixed. I then asked it to "mitigate any errors that could occur to the bridge". It added a port discovery file, per-request token re-reads, and MCP crash handlers. I also got it to add Mac compatibility it previously didn't have since I was working off a Windows machine so it had only defaulted to a bridge that could work with Windows. In the end, it sufficiently made a OpenCode to VSCode MCP bridge where I had it write an HTML-based website with CSS about Chopin's life and music.










Youtube Link for Demo: https://www.youtube.com/watch?v=s67XJBdorMg