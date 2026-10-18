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



WHAT WORKS AND WHAT DOESN'T

The GUI is movable, flexible, and fully useable, images are mostly pulled successfully with mismatches being hidden for the most part. The images retrieved don't always match the user's prompt. Plus the only 8 sources are minimal compared to how many images one could find from searching Google by themselves. It is on its way to doing what I want, but as it stands now, it does not solve the problem it was made to solve. Overall, the scale and specifity of images is lacking in its current iteration.




PEER RUN


Peer Run Test for Nora Wentz 

Test Done by Nora Yassin

The tool opens and works just fine. I tested It by searching for houses in Saudi Arabia from 1994, then broadened my searches to 20th century architecture in Saudi Arabia, the Middle East, and Europe. The Saudi searches returned unrelated images or nothing, the Middle East search reported 27 results without visible images, but the Europe search displayed many correct  images.




WHAT I'LL FIX

I need more image APIs to get more variety in my images. My image retriever has a Euro-centric bias given that the sources I've chosen all originate from the West. To fix this, I'll see if I can get access to more niche image providers from different countries and maybe one of Google's image APIs if I'm lucky.
