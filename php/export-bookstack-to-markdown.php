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
$apiUrl = getenv('BS_URL') ?: 'https://wiki.lan.bladewdr.xyz'; // http://bookstack.local/
$clientId = getenv('BS_TOKEN_ID') ?: 'SdSzww12Gf0F1Sy5ogIjeir6i3qEzuBf';
$clientSecret = getenv('BS_TOKEN_SECRET') ?: 'jKthboSLe53oXjNUEPJGyv4RNIdFsUzC';

// Export Format & Location
// Can be provided as a arguments when calling the script
// or be hard-coded as strings below.
$exportFormat = $argv[1] ?? 'markdown';
// $exportLocation = $argv[2] ?? './';
$exportLocation = $argv[2] ?? '/home/scott/test';

$outDir = realpath($exportLocation);

// Mapping for export formats to the resulting export file extensions
$extensionByFormat = [
    'pdf' => 'pdf',
    'html' => 'html',
    'plaintext' => 'txt',
    'markdown' => 'md',
];

$extension = $extensionByFormat[$exportFormat] ?? $exportFormat;

exportPages($outDir,$extension); //$pages is the list of all pages in a json format.

function listAllPages(): array {
    global $apiUrl, $clientId, $clientSecret;
    //build the API url for the GET request.
    $endpoint = "/api/pages";
    $url = rtrim($apiUrl, '/') . $endpoint;
    $options = [
        'http' => [
            'method' => 'GET',
            'header'=> "Authorization: Token {$clientId}:{$clientSecret}",
            ],
                
    ];
    
    $context = stream_context_create($options);
    $response = file_get_contents($url, false, $context);

    if ($response === false) {
        echo 'failed to retreive data from API.';
    }

    $data = json_decode($response, true);

    if ($data === null) {
        echo 'Error decoding JSON data.';
    }

    return $data;


}
//end of function
//
//notes: the array items will always be 16 elements long, and their positions will not change.
//Instead of iterating over the array to parse it, set the variables to the specific elements I need.
//
//
function exportPages($outDir,$extension) {

   $pagesList = listAllPages();
   
    if (isset($pagesList['data'])) {
        foreach ($pagesList['data'] as $item) {
            $id = $item['id'];
            $book_slug = $item['book_slug'];
            $chapter_id = $item['chapter_id'];
            $name = $item['name'];
            $slug = $item['slug'];

            $bookDir = $outDir . '/' . $book_slug . "/"; //the directory we're going to put our note in.
            if (!is_dir($bookDir)) {

                mkdir($bookDir,0755,true);
                echo "New directory $bookDir created.\n";
                $pageContent = pageToFile($id);
                $filePath = $bookDir . $slug . '.' . $extension;
                file_put_contents($filePath,$pageContent);


            }
            else {
                echo "File exported.\n";
                $pageContent = pageToFile($id);
                $filePath = $bookDir . $slug . '.' . $extension;
                file_put_contents($filePath,$pageContent);
            }
             }
    } 


    }

function pageToFile($id) {
    global $apiUrl, $clientId, $clientSecret, $exportFormat;
    $endpoint = "/api/pages/$id/export/$exportFormat";
    $url = rtrim($apiUrl, '/') . $endpoint;
    $options = [
        'http' => [
            'method' => 'GET',
            'header'=> "Authorization: Token {$clientId}:{$clientSecret}",
            ],
                
    ];
     
    $context = stream_context_create($options);
    return file_get_contents($url, false, $context);

}



