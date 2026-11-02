This is an AI-generated tool written in Python for Adobe Photoshop. It's an image reference retriever that pulls images based on a user's prompt from various APIs. Those being the National Gallery of Art, the Library of Congress, the Metropolitan Museum of Art, Wikimedia Commons, Cleveland Museum of Art, Art Institute of Chicago, Wellcome Collection, and OpenVerse.

PREREQUISITES

Python 3.11+

Brew (Mac Only)

Adobe Photoshop (CC 2018+)

Requests, Pillow, Reportlab

A stable internet connection

WINDOWS USERS:

Python 3.11 Install: winget install Python.Python.3.11

Photoshop Install: Go to https://www.adobe.com/products/photoshop.html and purchase a subscription to Photoshop then install the Adobe Creative Cloud desktop application file and run it. After that, open the Adobe Creative Cloud app and find Photoshop in your app list. Click install to install Photoshop.

Requests, Pillow, Reportlab Install: pip install requests pillow reportlab

MAC USERS:

Brew Install: winget install Python.Python.3.11

Python 3.11 Install: brew install python@3.11

Photoshop Install: Go to https://www.adobe.com/products/photoshop.html and purchase a subscription to Photoshop then install the Adobe Creative Cloud desktop application file and run it. After that, open the Adobe Creative Cloud app and find Photoshop in your app list. Click install to install Photoshop.

Requests, Pillow, Reportlab Install: pip install requests pillow reportlab

HOW TO RUN IT

WINDOWS USERS:

First, download ai-reference-retriever-portable.zip then extract the zip file

Next, open Photoshop and then open the ai-reference-retriever-portable folder and double-click the run.bat file. (This installs the necessary libraries upon first launch and opens the GUI of the tool)

MAC USERS:

Next, open Photoshop and then open the ai-reference-retriever-portable folder and double-click the run.sh file. (This installs the necessary libraries upon first launch and opens the GUI of the tool)

WHAT DOESN'T WORK YET AND WHAT I'D BUILD NEXT

The image recall still has flaws given how it's pulling from descriptors alone which is a double-edged sword since some of the sources' descriptions are less than ideal for this tool. I want subjects of the image rather than documents, maps, or people named the image (a man had the last name of cat so he would show up when searching for cats). Specifictiy and huan knowledge of the prompt's subject is lacking given how AI in its current state doesn't recognize the way people do. The image dismissal that was supposed to prompt machine learning is unstable and it saves cache of the images, inflating the file size and doing nothing to improve the AI's recognition and sorting of images. What I'd do next if I were to improve this tool further, is to input open source free use datasets to train the AI on image recognition as well as do further code and speed optimizations. For the time that I had to complete this, I do think my tool is helpful in its current state. I even saved an image the AI retriever recommended me. It was an illustration of a messenger pigeon created by Blanca Saccomano from a public library in Bulgaria. I doubt I would have found that on my own.


PEER RUN

Peer Run Test for Nora Wentz

Test Done by Nora Yassin

The tool opens and works just fine. I tested It by searching for houses in Saudi Arabia from 1994, then broadened my searches to 20th century architecture in Saudi Arabia, the Middle East, and Europe. The Saudi searches returned unrelated images or nothing, the Middle East search reported 27 results without visible images, but the Europe search displayed many correct images.

WHAT I'LL FIX

I need more image APIs to get more variety in my images. My image retriever has a Euro-centric bias given that the sources I've chosen all originate from the West. To fix this, I'll see if I can get access to more niche image providers from different countries and maybe one of Google's image APIs if I'm lucky.

WHAT I FIXED

With my AI agent, I added diverse sources like Rijksmuseum, Harvard Art Museum, and the Smithsonian Museum. These three sources have more non-European art though they still are Western-based primarily. I also changed the GUI to match the design language of Photoshop, made it a plugin easily accessible as a panel one can click on without breaking their workflow. I improved the GUI further by getting rid of jitters that occured when resizing the tool window or scrolling.


YOUTUBE LINK:

https://www.youtube.com/watch?v=YaVoKIWzThI