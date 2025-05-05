import streamlit as st
import pandas as pd
import sqlite3
import requests
import json
import io
 
# --- CONFIG ---
GROQ_API_KEY = "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"  # 🔐 Replace with your Groq API key
GROQ_MODEL = "llama3-70b-8192"
 
# --- Function to call Groq ---
def call_groq_llm(prompt):
    url = "https://api.groq.com/openai/v1/chat/completions"
    headers = {
        "Authorization": f"Bearer {GROQ_API_KEY}",
        "Content-Type": "application/json"
    }
    payload = {
        "model": GROQ_MODEL,
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are a SQLite SQL expert. Only return valid SELECT SQL queries for SQLite. "
                    "Do not use markdown, comments, or explanation."
                )
            },
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.2
    }
 
    response = requests.post(url, headers=headers, data=json.dumps(payload))
    response.raise_for_status()
    result = response.json()
    return result["choices"][0]["message"]["content"].strip("```sql").strip("```").strip()
 
# --- Case-Insensitive SQL Helper ---
def make_case_insensitive_sql(query, df_columns):
    for column in df_columns:
        query = query.replace(f"'{column}'", f"LOWER({column})")
        query = query.replace(f" = '{column}'", f" LIKE LOWER('{column}')")
    return query
 
# --- Streamlit App ---
st.set_page_config(page_title="LLM SQL Assistant", layout="centered")
st.title("📊 LLM-Powered SQL Assistant")
 
uploaded_file = st.file_uploader("📂 Upload your CSV or Excel file", type=["csv", "xlsx"])
 
if uploaded_file:
    try:
        # Read file
        if uploaded_file.name.endswith(".csv"):
            df = pd.read_csv(uploaded_file)
        else:
            df = pd.read_excel(uploaded_file)
 
        # Normalize column names
        df.columns = df.columns.str.strip().str.replace(" ", "_").str.replace("-", "_")
 
        # Show preview
        st.success(f"✅ Loaded `{uploaded_file.name}` successfully.")
        st.subheader("📄 Data Preview")
        st.dataframe(df.head())
 
        # Load to SQLite
        conn = sqlite3.connect(":memory:")
        df.to_sql("company_data", conn, index=False, if_exists="replace")
 
        # User enters question
        user_question = st.text_input("❓ Ask a question about the data")
 
        if user_question:
            # Prompt for Groq
            prompt = f"""
            You are a SQLite SQL expert.
            You are given a table named `company_data` with the following columns:
            {', '.join(df.columns)}.
 
            Write a valid SQLite SELECT query to answer the question:
            \"{user_question}\"
 
            Do not include markdown, explanation, or comments.
            Use proper SQLite syntax only.
            """
 
            with st.spinner("🤖 Generating SQL using Groq..."):
                sql_query = call_groq_llm(prompt)
                sql_query = make_case_insensitive_sql(sql_query, df.columns)
 
            st.subheader("📌 Generated SQL")
            user_sql = st.text_area("You can edit the SQL query if needed:", value=sql_query, height=150)
 
            if st.button("▶️ Run SQL Query"):
                try:
                    result_df = pd.read_sql_query(user_sql, conn)
                    if result_df.empty:
                        st.warning("⚠️ Query ran successfully but returned no results.")
                    else:
                        st.subheader("📊 Query Result")
                        st.dataframe(result_df)
                except Exception as e:
                    st.error(f"❌ Error executing SQL: {e}")
 
    except Exception as e:
        st.error(f"❌ Failed to read file: {e}")
else:
    st.info("📁 Upload a CSV or Excel file to get started.")
