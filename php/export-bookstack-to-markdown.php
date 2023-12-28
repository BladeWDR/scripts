#!/usr/bin/env php
<?php

// API Credentials
// You can either provide them as environment variables
// or hard-code them in the empty strings below.
$apiUrl = getenv('BS_URL') ?: ''; // http://bookstack.local/
$clientId = getenv('BS_TOKEN_ID') ?: '';
$clientSecret = getenv('BS_TOKEN_SECRET') ?: '';

// Export Format & Location
// Can be provided as a arguments when calling the script
// or be hard-coded as strings below.
$exportFormat = $argv[1] ?? 'markdown';
// $exportLocation = $argv[2] ?? './';
$exportLocation = $argv[2] ?? './';

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

//return the page list so we can get the page details.
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

//Export the pages to a file.
//use the array built by listAllPages() to build the folder structure.
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
