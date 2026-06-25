# Airbnb Text Analytics — Business Value from Listing Descriptions

Text-mining analysis of **5,000+ Airbnb listings** to quantify how the *language*
hosts use in their descriptions affects pricing, engagement, and review
performance. Built in **R** against MongoDB's `sample_airbnb` dataset, with an
interactive **R Shiny** dashboard.

**Author:** Valentine Dube
**Course:** Business Analysis with Unstructured Data (Data Visualization & Text Analytics)

---

## What it does

The pipeline pulls listing text live from MongoDB Atlas and runs four
text-mining frameworks:

| Framework | Technique | Business question |
|-----------|-----------|-------------------|
| **Sentiment analysis** | NRC, BING, AFINN lexicons | What emotions do hosts convey, and do positive descriptions earn higher prices/ratings? |
| **TF-IDF + bigrams** | Term weighting & n-grams | Which unique features distinguish high-performing listings? |
| **Topic modeling** | LDA (k = 6) | What themes exist across listings, and which command premiums? |
| **Dashboard** | R Shiny | Interactive KPIs, filters, and four decision-support visuals |

## Key findings

- **Sentiment → price:** Very Positive listings average **$143 vs $121** for
  Neutral — an ~18% premium (sentiment–price correlation **r = 0.52**).
- **Differentiation:** ~70% of descriptions use generic words ("nice",
  "comfortable"); unique descriptors ("villa", "loft", "guesthouse") correlate
  with **~30% higher engagement** by review volume.
- **Topics:** Beach-themed properties command a **20–30% premium** over generic
  urban apartments.
- **Reviews:** **50–100 reviews** is the sweet spot for credibility and pricing
  power; 500+ reviews shows commoditization.
- Projected **30–40% revenue upside** through content optimization.

See [`report/`](report/) for the full write-up and the appendix of text-analysis
outputs and Shiny visuals.

---

## Project structure

```
airbnb-text-analytics/
├── R/
│   └── airbnb_text_analytics.R   # full pipeline: Mongo → sentiment → TF-IDF → LDA → Shiny
├── report/
│   ├── Airbnb_Report_Valentine_Dube.pdf
│   └── Appendix_Text_Analyses_and_RShiny_visuals.pdf
├── .Renviron.example             # template for the MongoDB connection string
├── .gitignore
└── README.md
```

## Getting started

### 1. Prerequisites
- R (4.x recommended)
- A MongoDB Atlas cluster loaded with the `sample_airbnb` sample dataset

### 2. Configure the database connection
Credentials are **not** stored in the code. Copy the example file and add your
own connection string:

```bash
cp .Renviron.example .Renviron
```

Then edit `.Renviron`:

```
MONGO_URI=mongodb+srv://<username>:<password>@<cluster-host>/?appName=Cluster0
```

`.Renviron` is gitignored, so your credentials stay local. Restart R so it loads
the variable.

### 3. Install packages and run

```r
install.packages(c("mongolite", "tidyverse", "tidytext", "textdata",
                   "topicmodels", "widyr", "igraph", "ggraph", "wordcloud", "shiny"))

# from the repo root
source("R/airbnb_text_analytics.R")
```

The script connects to MongoDB, runs the analyses (saving plots as `.png` and a
cleaned dataset to `airbnb_clean.csv`), and launches the Shiny dashboard.

> **Note:** the dataset lives in MongoDB and is fetched at runtime — no data is
> stored in this repo.

## Tech stack

`R` · `mongolite` · `tidytext` · `topicmodels` · `dplyr`/`tidyr` · `ggplot2` · `shiny`
