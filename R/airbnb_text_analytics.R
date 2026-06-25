###############################################################################
# AIRBNB DESCRIPTION TEXT ANALYTICS PROJECT
# Author: Valentine
# Course: Data Visualization and Text Analytics
# Description: Comprehensive text mining analysis of Airbnb listing descriptions
###############################################################################

# Install required packages (run once)
 install.packages(c("mongolite", "tidyverse", "tidytext", "textdata", 
                   "topicmodels", "widyr", "igraph", "ggraph", "wordcloud","shiny"))


library(mongolite)
library(dplyr)
library(stringr)
library(tidytext)
library(ggplot2)
library(tidyr)
library(shiny)

###############################################################################
# PART 1: MONGODB CONNECTION AND DATA EXTRACTION
###############################################################################

# MongoDB Connection Setup
# The connection string is read from the MONGO_URI environment variable so that
# credentials are never committed to source control. Copy .Renviron.example to
# .Renviron and set your own connection string there (see README).
connection_string <- Sys.getenv("MONGO_URI")
if (connection_string == "") {
  stop("MONGO_URI is not set. Copy .Renviron.example to .Renviron, add your ",
       "MongoDB connection string, then restart R.")
}

# Connect to Airbnb collection
airbnb_collection <- mongo(
  collection = "listingsAndReviews",
  db = "sample_airbnb",
  url = connection_string
)

# Test the connection
cat("Testing connection...\n")
count <- airbnb_collection$count()
cat("SUCCESS! Found", count, "Airbnb listings\n")

# Extract relevant fields from MongoDB
airbnb_raw <- airbnb_collection$find(
  query = '{}',
  fields = '{"_id": 1, "name": 1, "summary": 1, "description": 1, 
            "space": 1, "neighborhood_overview": 1, "property_type": 1, 
            "room_type": 1, "price": 1, "bedrooms": 1, 
            "address.country": 1, "address.market": 1, "number_of_reviews": 1,
            "review_scores.review_scores_rating": 1}'
)

library(dplyr)
library(tidytext)

airbnb_data <- airbnb_raw %>%
  mutate(
    airbnb_new = paste(property_type, room_type, description, space, neighborhood_overview, sep = " ")
  ) %>%
  select(airbnb_new)

airbnb_tokens <- airbnb_data %>%
  unnest_tokens(word, airbnb_new) %>%
  anti_join(stop_words, by = "word")

###############################################################################
# TEXT MINING FRAMEWORK 1: SENTIMENT ANALYSIS
# Business Question: What emotions do hosts convey in their descriptions?
# Are positive descriptions correlated with higher ratings or prices?
###############################################################################
#NRC Sentiments
airbnb_nrc <- airbnb_tokens %>%
  inner_join(
    get_sentiments("nrc"),
    by = "word",
    relationship = "many-to-many"
  )

# Count sentiments
nrc_counts <- airbnb_nrc %>%
  count(sentiment, sort = TRUE)

# View counts
print(nrc_counts)

# Plot sentiments
ggplot(nrc_counts, aes(x = reorder(sentiment, n), y = n)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "NRC Sentiment Distribution in Airbnb Listings",
    x = "Sentiment",
    y = "Count"
  ) +
  theme_light()


# 2. Most common positive and negative words (BING LEXICONS)

airbnb_bing <- airbnb_tokens %>%
  inner_join(
    get_sentiments("bing"),
    by = "word"
  )

# Count top words by sentiment
bing_words <- airbnb_bing %>%
  count(word, sentiment, sort = TRUE) %>%
  group_by(sentiment) %>%
  slice_max(n, n = 15) %>%
  ungroup()

# View results
print(bing_words)

# Plot top positive and negative words
ggplot(bing_words, aes(x = reorder(word, n), y = n, fill = sentiment)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ sentiment, scales = "free_y") +
  coord_flip() +
  labs(
    title = "Most Common Positive and Negative Words in Airbnb Listings",
    x = NULL,
    y = "Frequency"
  ) +
  theme_minimal()

# Save plot
ggsave("sentiment_words.png", width = 10, height = 6, dpi = 300)


# Join with AFINN sentiment lexicon
airbnb_afinn <- airbnb_tokens %>%
  inner_join(
    get_sentiments("afinn"),
    by = "word"
  )

# Count words with sentiment scores
afinn_words <- airbnb_afinn %>%
  count(word, value, sort = TRUE)

# View results
print(head(afinn_words, 20))

# Overall sentiment score
afinn_score <- airbnb_afinn %>%
  summarise(total_sentiment = sum(value, na.rm = TRUE))

print(afinn_score)

# Plot top sentiment-scored words
top_afinn_words <- airbnb_afinn %>%
  count(word, value, sort = TRUE) %>%
  slice_max(n, n = 20)

ggplot(top_afinn_words, aes(x = reorder(word, n), y = n)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Top AFINN Sentiment Words in Airbnb Listings",
    x = "Word",
    y = "Frequency"
  ) +
  theme_minimal()

# Save plot
ggsave("afinn_words.png", width = 10, height = 6, dpi = 300)



###############################################################################
# TEXT MINING FRAMEWORK 2: TF-IDF ANALYSIS
# Business Question: What unique features do hosts emphasize in different markets?
# What distinguishes high-performing listings?
###############################################################################


##TF-IDF and Bigrams

# Add a document ID for each Airbnb listing
airbnb_data <- airbnb_raw %>%
  mutate(
    listing_id = row_number(),
    airbnb_new = paste(
      property_type,
      room_type,
      description,
      space,
      neighborhood_overview,
      sep = " "
    )
  ) %>%
  select(listing_id, airbnb_new)


airbnb_words <- airbnb_data %>%
  unnest_tokens(word, airbnb_new) %>%
  anti_join(stop_words, by = "word") %>%
  count(listing_id, word, sort = TRUE)

airbnb_tfidf <- airbnb_words %>%
  bind_tf_idf(word, listing_id, n) %>%
  arrange(desc(tf_idf))

# View top TF-IDF words
head(airbnb_tfidf, 20)

# Plot top 20 TF-IDF words overall
top_tfidf <- airbnb_tfidf %>%
  slice_max(tf_idf, n = 20)

ggplot(top_tfidf, aes(x = reorder(word, tf_idf), y = tf_idf)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Top TF-IDF Words in Airbnb Listings",
    x = "Word",
    y = "TF-IDF"
  ) +
  theme_minimal()

ggsave("airbnb_tfidf.png", width = 10, height = 6, dpi = 300)

# -----------------------------
# 2. BIGRAMS
# -----------------------------

airbnb_bigrams <- airbnb_data %>%
  unnest_tokens(bigram, airbnb_new, token = "ngrams", n = 2)

bigram_counts <- airbnb_bigrams %>%
  separate(bigram, into = c("word1", "word2"), sep = " ") %>%
  filter(!word1 %in% stop_words$word,
         !word2 %in% stop_words$word) %>%
  count(word1, word2, sort = TRUE)

# View top bigrams
head(bigram_counts, 20)

# Plot top 20 bigrams
top_bigrams <- bigram_counts %>%
  mutate(bigram = paste(word1, word2)) %>%
  slice_max(n, n = 20)

ggplot(top_bigrams, aes(x = reorder(bigram, n), y = n)) +
  geom_col() +
  coord_flip() +
  labs(
    title = "Top Bigrams in Airbnb Listings",
    x = "Bigram",
    y = "Frequency"
  ) +
  theme_minimal()

ggsave("airbnb_bigrams.png", width = 10, height = 6, dpi = 300)




###############################################################################
# TEXT MINING FRAMEWORK 3: TOPIC MODELING (LDA)
# Business Question: What are the main themes in Airbnb descriptions?
# Can we categorize listings based on their description content?
###############################################################################

# Create Airbnb text data with document ID
airbnb_data <- airbnb_raw %>%
  mutate(
    listing_id = row_number(),
    airbnb_new = paste(
      property_type,
      room_type,
      description,
      space,
      neighborhood_overview,
      sep = " "
    )
  ) %>%
  select(listing_id, airbnb_new)

# Tokenize and remove stop words
airbnb_tokens <- airbnb_data %>%
  unnest_tokens(word, airbnb_new) %>%
  anti_join(stop_words, by = "word")

# Create document-term matrix
airbnb_dtm <- airbnb_tokens %>%
  count(listing_id, word) %>%
  cast_dtm(listing_id, word, n)

# Run topic model
set.seed(12345)
airbnb_lda <- LDA(airbnb_dtm, k = 6)

# Extract top words per topic
airbnb_topics <- tidy(airbnb_lda, matrix = "beta")

top_terms_per_topic <- airbnb_topics %>%
  group_by(topic) %>%
  slice_max(beta, n = 10) %>%
  ungroup()

print(top_terms_per_topic)

# Plot top words by topic
topic_plot <- top_terms_per_topic %>%
  mutate(term = reorder_within(term, beta, topic)) %>%
  ggplot(aes(term, beta, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~topic, scales = "free") +
  coord_flip() +
  scale_x_reordered() +
  labs(
    title = "Topic Modeling of Airbnb Listings",
    x = NULL,
    y = "Beta"
  ) +
  theme_minimal()

topic_plot

ggsave("lda_topics.png", topic_plot, width = 12, height = 8, dpi = 300)



library(dplyr)

final_df_clean <- airbnb_raw %>%
  mutate(
    listing_id = row_number(),
    price_numeric = as.numeric(gsub("\\$|,", "", as.character(price))),
    bedrooms = as.numeric(bedrooms),
    rating = sapply(review_scores, function(x) {
      if (is.null(x) || length(x) == 0) {
        NA_real_
      } else if (!is.null(names(x)) && "review_scores_rating" %in% names(x)) {
        as.numeric(x[["review_scores_rating"]][1])
      } else {
        NA_real_
      }
    })
  ) %>%
  select(
    listing_id,
    property_type,
    room_type,
    price_numeric,
    bedrooms,
    number_of_reviews,
    rating
  )

write.csv(final_df_clean, "airbnb_clean.csv", row.names = FALSE)

###########################################################################################################################
#Creation of raw base dataset incoporating text, numeric and sentimental columns
library(dplyr)
library(tidyr)
library(tidytext)
library(topicmodels)
library(tm)
library(broom)

# 1. Build one base dataset first
final_df <- airbnb_raw %>%
  mutate(
    listing_id = row_number(),
    price_numeric = as.numeric(gsub("\\$|,", "", as.character(price))),
    bedrooms = as.numeric(bedrooms),
    rating = sapply(review_scores, function(x) {
      if (is.null(x) || length(x) == 0) {
        NA_real_
      } else if (!is.null(names(x)) && "review_scores_rating" %in% names(x)) {
        as.numeric(x[["review_scores_rating"]][1])
      } else {
        NA_real_
      }
    }),
    text = paste(property_type, room_type, description, space, neighborhood_overview, sep = " ")
  ) %>%
  select(
    listing_id,
    property_type,
    room_type,
    price_numeric,
    bedrooms,
    number_of_reviews,
    rating,
    text
  )

# 2. Tokenize from THIS SAME dataset
tokens <- final_df %>%
  unnest_tokens(word, text) %>%
  anti_join(stop_words, by = "word")

# 3. Create listing-level sentiment score
sentiment_df <- tokens %>%
  inner_join(get_sentiments("afinn"), by = "word") %>%
  group_by(listing_id) %>%
  summarise(sentiment_score = sum(value, na.rm = TRUE), .groups = "drop")

# 4. Join sentiment back
final_df <- final_df %>%
  left_join(sentiment_df, by = "listing_id")

# 5. Create DTM for topic modeling
dtm <- tokens %>%
  count(listing_id, word) %>%
  cast_dtm(document = listing_id, term = word, value = n)

# 6. Run LDA
set.seed(12345)
lda_model <- LDA(dtm, k = 6)

# 7. Extract dominant topic per listing
topics <- tidy(lda_model, matrix = "gamma")

dominant_topics <- topics %>%
  group_by(document) %>%
  slice_max(gamma, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  transmute(
    listing_id = as.integer(document),
    dominant_topic = topic
  )

# 8. Join dominant topic back
final_df <- final_df %>%
  left_join(dominant_topics, by = "listing_id")

# 9. Replace missing sentiment if a listing had no AFINN words
final_df_clean <- final_df %>%
  mutate(
    sentiment_score = ifelse(is.na(sentiment_score), 0, sentiment_score)
  ) %>%
  select(
    listing_id,
    property_type,
    room_type,
    price_numeric,
    bedrooms,
    number_of_reviews,
    sentiment_score,
    dominant_topic
  )

# 10. Check before saving
head(final_df_clean)
summary(final_df_clean$sentiment_score)
table(is.na(final_df_clean$dominant_topic))

# 11. Save
write.csv(final_df_clean, "airbnb_clean.csv", row.names = FALSE)

## RUN APP
###############################################################

shinyApp(ui = ui, server = server)

