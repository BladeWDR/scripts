#!/usr/bin/env php
<?php

/* Process: query https://wiki-url/api/pages and get a list of all pages in the bookstack instance.
* iterate through the json data returned and use it to first build the folder structure, then build a url for each page.
* Use that url to export each page as markdown.
* example: https://demo.bookstackapp.com/api/pages/{id}/export/markdown 
*/ 

//vars
// API Credentials
// You can either provide them as environment variables
// or hard-code them in the empty strings below.
$apiUrl = getenv('BS_URL') ?: 'https://wiki.lan.bladwdr.xyz/api/pages'; // http://bookstack.local/
$clientId = getenv('BS_TOKEN_ID') ?: 'SdSzww12Gf0F1Sy5ogIjeir6i3qEzuBf';
$clientSecret = getenv('BS_TOKEN_SECRET') ?: 'jKthboSLe53oXjNUEPJGyv4RNIdFsUzC';

// Export Format & Location
// Can be provided as a arguments when calling the script
// or be hard-coded as strings below.
$exportFormat = $argv[1] ?? 'pdf';
$exportLocation = $argv[2] ?? './';

$pages = listAllPages($apiUrl, $clientId, $clientSecret); //$pages is the list of all pages in a json format.
$outDir = realpath($exportLocation);

// Mapping for export formats to the resulting export file extensions
$extensionByFormat = [
    'pdf' => 'pdf',
    'html' => 'html',
    'plaintext' => 'txt',
    'markdown' => 'md',
];

function listAllPages($apiUrl, $clientId, $clientSecret): array {
    $options = [
        'http' => [
            'method' => 'GET',
            'header' => 'Content-Type: application/json', 'Authorization: Token {$clientId}:{$clientSecret}'
            ],
                
    ];
    
    $context = stream_context_create($options);
    $response = file_get_contents($apiUrl, false, $context);

    if ($response === false) {
        return 'failed to retreive data from API.';
    }

    $data = json_decode($response, true)

    if ($data === null) {
    return 'Error decoding JSON data.';
    }


}
//end of function

print_r($response)
