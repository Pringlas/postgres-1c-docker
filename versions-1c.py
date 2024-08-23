#!/usr/bin/env python3

import glob
import json
import requests
import sys
import bs4

OUTPUT_FILE = "versions.json"

class ReleasesClient(object):
    __releases_url = "https://releases.1c.ru"
    __login_url = "https://login.1c.ru"

    def __init__(self, user, password):
        self.user = user
        self.password = password
        self.auth = (user, password)
        self.session = requests.Session()

    def releases_request(self, path, authorized=False):
        url = self.__releases_url + path
        if authorized:
            url = self.get_authorized_url(self.__releases_url + path)

        response = self.session.get(url, auth = self.auth )

        return response

    def get_authorized_url(self, url):
        ticket = self.ticket_request(url)
        authorized_url = self.__login_url + "/ticket/auth?token=" + ticket

        return authorized_url

    def ticket_request(self, url = __releases_url):
        response = self.session.post(self.__login_url + "/rest/public/ticket/get", 
            json = {
                "login": self.user,
                "password": self.password,
                "serviceNick": url
            },
            auth = self.auth)

        if response.status_code != 200:
            raise Exception
                
        return response.json()["ticket"]   

    def get_download_url(self, path):
        self.releases_request("/", True)
        response = self.releases_request(path)

        if response.status_code != 200:
            raise Exception
        
        parser = bs4.BeautifulSoup(response.text, "html.parser")
        url = parser.find("div", class_="downloadDist").a.get("href")

        return url

def get_major_verions():
    return [version_dir.replace("/", "") for version_dir in sorted(glob.glob("??/"))]

def get_distros_versions():
    return {"debian": ["bookworm", "bullseye"]}

def get_versions_json():
    versions_json = {}
    major_versions: List[str] = get_major_verions()
    versions = get_latest_versions()
    
    for major_version in major_versions:
        version_json = {"major": major_version,
                        "variants": [],
                        "version": versions[major_version]}
        
        distros_versions = get_distros_versions()
        for distro_versions in distros_versions.values():
            for distro_version in distro_versions:
                version_json["variants"].append(distro_version)
                version_json[distro_version] = {"version": versions[major_version]}

        versions_json[major_version] = version_json
        print(f"{major_version}")

    return versions_json

def get_latest_versions():
    response = get_releases_list_request()
    versions = parse_latest_versions(response)

    for key in versions.keys():
        value = versions[key]
        versions[key] = f"{value[0]}.{value[1]}-{value[2]}.1C"

    return versions

def parse_latest_versions(response):
    versions = {}
    parser = bs4.BeautifulSoup(response, "html.parser")

    cells = parser.find_all("td", class_ = "versionColumn")

    for cell in cells:
        full_version:str = cell.a.text.strip()
        comparable_representation = [elem for elem in map(lambda version_part: int(version_part), 
            full_version.replace("-", ".").split(".")[:-1])]
        major = str(comparable_representation[0])
        if versions.get(major) == None:
            versions[major] = comparable_representation
        
        if versions.get(major) < comparable_representation:
            versions[major] = comparable_representation

    return versions

def get_releases_list_request():
    response_body = releases_request("/project/AddCompPostgre?allUpdates=true")
    return response_body
    
def releases_request(path):
    client = ReleasesClient(sys.argv[1], sys.argv[2])
    response = client.releases_request(path, True)

    if response.status_code != 200:
        raise Exception

    return response.text

def main():
    versions_json = get_versions_json()

    with open(OUTPUT_FILE, "w") as file:
        file.write(json.dumps(versions_json, sort_keys = True))

if __name__ == "__main__":
    main()