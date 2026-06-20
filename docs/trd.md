# Personal AI Vault - Technical Requirements Document (TRD)

## Technology Stack

### Mobile

* Flutter
* Dart
* Riverpod
* GoRouter

### Backend

* FastAPI
* Python

### Database

MongoDB

Reason:

Identity Graph data is naturally document-oriented and relationship-driven.

Stores:

* User Nodes
* Relationship Nodes
* Facts
* Confidence Scores
* Metadata

---

### Object Storage

* Cloudflare R2
* AWS S3

Stores:

* Images
* PDFs
* Document Versions

---

### Search Engine

* OpenSearch

Supports:

* Full Text Search
* Semantic Search
* Metadata Search

---

### AI Layer

Components:

* OCR Engine
* Document Classifier
* Entity Extraction
* Relationship Resolver
* Autofill Mapper

---

## System Architecture

Flutter App

↓

API Gateway

↓

Authentication Service

↓

Document Service

↓

OCR Service

↓

AI Extraction Service

↓

Identity Graph Service

↓

Search Service

↓

Autofill Service

---

## Core Data Model

### User Node

Contains:

* Name
* DOB
* Email
* Phone
* Occupation

---

### Person Node

Contains:

* Name
* Relationship
* Confidence

Examples:

* Father
* Mother
* Sister
* Spouse

---

### Fact Node

Contains:

* Value
* Source
* Confidence
* Last Updated

---

### Document Node

Contains:

* Type
* Upload Date
* Owner
* Metadata

---

## OCR Pipeline

Document

↓

Preprocessing

↓

OCR

↓

Layout Analysis

↓

Entity Extraction

↓

Identity Graph Update

---

## AI Extraction

Extract:

* Names
* Addresses
* Dates
* Education
* Employment
* IDs

Every extraction returns:

Value

Confidence

Source Document

---

## Relationship Engine

Purpose:

Prevent identity contamination.

Example:

Ration Card

↓

Detect Multiple People

↓

Create Separate Nodes

↓

Request Confirmation

↓

Store Relationship

---

## Search Architecture

Uses:

* Embeddings
* Full Text Search
* Metadata Filters

Queries:

* My passport
* Father's Aadhaar
* Expired documents

---

## Autofill Service

Android Autofill Framework

Responsibilities:

* Form Detection
* Field Mapping
* Context Suggestions

---

## Security

### Encryption

AES-256

### Transport

TLS 1.3

### Authentication

JWT

Refresh Tokens

### Secrets

Managed through Vault

---

## Future Architecture

* Local LLM
* Offline OCR
* Family Vault
* Verification APIs
* Enterprise Integrations
