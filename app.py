import streamlit as st
import joblib
import pandas as pd
import zipfile
import os

# --- 1. PAGE CONFIGURATION ---
st.set_page_config(
    page_title="Nashville Real Estate AVM",
    page_icon="🏙️",
    layout="wide"
)

# --- 2. CUSTOM CSS INJECTION ---
st.markdown("""
<style>
.stApp {
    background: linear-gradient(135deg, #0f172a, #1e293b);
    color: #f1f5f9;
}
footer {visibility: hidden;}
.block-container {
    padding-top: 2rem;
    padding-bottom: 2rem;
}
.card {
    background: white;
    padding: 25px;
    border-radius: 14px;
    box-shadow: 0 10px 25px rgba(0,0,0,0.2);
    margin-bottom: 20px;
}
.price {
    font-size: 42px;
    font-weight: 700;
    color: #16a34a;
    margin-bottom: 0;
}
.stButton>button {
    width: 100%;
    height: 48px;
    border-radius: 10px;
    background-color: #2563eb;
    color: white;
    font-weight: 600;
    border: none;
    transition: 0.3s;
}
.stButton>button:hover {
    background-color: #1d4ed8;
}
.custom-footer {
    margin-top: 60px;
    padding: 30px;
    background: #0f172a;
    border-radius: 12px;
    text-align: center;
    font-size: 14px;
    color: #cbd5e1;
}
[data-testid="stMetricLabel"] {
    color: #475569 !important;
}
[data-testid="stMetricValue"] {
    color: #0f172a !important;
}
</style>
""", unsafe_allow_html=True)

# --- 3. LOAD THE ML ENGINE ---
@st.cache_resource
def load_model():
    # If the .pkl file doesn't exist yet, extract it from the zip file
    if not os.path.exists("nashville_rf_model.pkl"):
        with zipfile.ZipFile("nashville_rf_model.zip", 'r') as zip_ref:
            zip_ref.extractall(".")
            
    model = joblib.load("nashville_rf_model.pkl")
    features = joblib.load("model_features.pkl")
    return model, features

model, features = load_model()
NASHVILLE_AVG = 450000

# --- 4. APP HEADER ---
st.title("🏙️ Nashville Automated Valuation Model")
st.caption("AI-powered real estate pricing engine using Davidson County housing data")
st.divider()

# --- 5. TWO-COLUMN LAYOUT ---
col1, col2 = st.columns([1,1])

with col1:
    st.subheader("🏡 Property Details")
    bedrooms = st.slider("Bedrooms", 1, 10, 3)
    full_bath = st.slider("Full Bathrooms", 1, 7, 2)
    half_bath = st.slider("Half Bathrooms", 0, 4, 0)
    acreage = st.number_input("Lot Size (Acres)", 0.1, 10.0, 0.5, step=0.1)
    age = st.slider("Property Age (Years)", 0, 150, 15)
    predict_button = st.button("Generate Valuation")

with col2:
    st.subheader("📊 Valuation Result")

    if predict_button:
        input_data = pd.DataFrame([[bedrooms, full_bath, half_bath, acreage, age]], columns=features)
        prediction = model.predict(input_data)[0]

        margin = prediction * 0.045
        low = prediction - margin
        high = prediction + margin
        diff = prediction - NASHVILLE_AVG
        diff_text = f"+${diff:,.0f} above avg" if diff > 0 else f"-${abs(diff):,.0f} below avg"

        st.markdown("<div class='card'>", unsafe_allow_html=True)
        st.markdown("<p style='color:#64748b;'>Estimated Market Value</p>", unsafe_allow_html=True)
        st.markdown(f"<p class='price'>${prediction:,.0f}</p>", unsafe_allow_html=True)
        st.markdown(f"<p style='color:#475569;'>Confidence Interval: ${low:,.0f} - ${high:,.0f}</p>", unsafe_allow_html=True)
        st.markdown("---")

        colA, colB = st.columns(2)
        with colA:
            st.metric("Vs Nashville Avg", diff_text)
        with colB:
            tier = "Premium / Luxury" if prediction > 750000 else "Mid-Market" if prediction > 350000 else "Starter Home"
            st.metric("Property Tier", tier)

        st.markdown("</div>", unsafe_allow_html=True)
        st.info(f"**AI Insight:** Property age ({age} yrs) and lot size ({acreage} acres) strongly influence this valuation.")
    else:
        st.markdown("<div class='card' style='text-align:center;'><p style='color:#94a3b8;'>Adjust inputs on the left and click <b>Generate Valuation</b> to see the AI's prediction.</p></div>", unsafe_allow_html=True)

# --- 6. POWER BI DASHBOARD SECTION (LIVE EMBED) ---
st.markdown("---")
st.subheader("📊 Market Analytics Dashboard")
st.markdown("<p style='color: #cbd5e1;'>Interact with the live Power BI dashboard below, connected directly to our Azure SQL database via DirectQuery.</p>", unsafe_allow_html=True)

# Your live Power BI URL
power_bi_url = "https://app.powerbi.com/view?r=eyJrIjoiZTM2ZGI3OGQtNjVjYS00ZTFlLWFmOTAtODUxZTg4MDU1ODhhIiwidCI6IjM0YmQ4YmVkLTJhYzEtNDFhZS05ZjA4LTRlMGEzZjExNzA2YyJ9"

# Embeds the live Power BI dashboard
st.markdown(f'<iframe title="Nashville Housing Dashboard" width="100%" height="650" src="{power_bi_url}" frameborder="0" allowFullScreen="true" style="border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.3);"></iframe>', unsafe_allow_html=True)

# --- 7. FOOTER ---
st.markdown("""
<div class='custom-footer'>
    <strong>Model & Dataset Information</strong><br><br>
    📊 Training Rows: ~20,600 | 📈 Testing Rows: ~5,150<br><br>
    Built with Python · Streamlit · Azure SQL · Scikit-Learn<br>
    Random Forest Regressor (R²: 0.468)<br><br>
    <em>Portfolio project. Not financial advice.</em>
</div>
""", unsafe_allow_html=True)
