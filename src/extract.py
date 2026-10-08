import requests

SOURCES = {
    "poolfund": "https://cbpfapi.unocha.org/vo1/odata/Poolfund",
    "contribution": "https://cbpfapi.unocha.org/vo1/odata/Contribution",
    "project_summary": "https://cbpfapi.unocha.org/vo1/odata/ProjectSummary",
}

def fetch(source):
    url = SOURCES[source]
    response = requests.get(url, timeout=300)
    response.raise_for_status()
    
    data = response.json()
    
    # Extract the record list if wrapped in an OData dictionary
    if isinstance(data, dict) and "value" in data:
        return data["value"]
    
    return data