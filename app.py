from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi.staticfiles import StaticFiles

app = FastAPI()

# Mount the directory containing the HTML file as a static directory
app.mount("/static", StaticFiles(directory="."), name="static")

@app.get("/", response_class=HTMLResponse)
async def read_root():
    # Read the HTML file and return its content as response
    with open("./helloworld.html", "r") as file:
        html_content = file.read()
    return HTMLResponse(content=html_content, status_code=200)
