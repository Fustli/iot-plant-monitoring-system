"""
Plant data scraper using Trefle API
Fetches optimal growing conditions for common houseplants
"""

import requests
import json
import time
import os
from typing import List, Dict, Optional
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()


# Most common houseplants to fetch
COMMON_PLANTS = [
    "Basil", "Tomato", "Sansevieria trifasciata", "Epipremnum aureum", "Chlorophytum comosum",
    "Spathiphyllum", "Aloe vera", "Monstera deliciosa", "Ficus lyrata", "Ficus elastica",
    "Zamioculcas zamiifolia", "Hedera helix", "Nephrolepis exaltata", "Crassula ovata", "Phalaenopsis",
    "Lavandula", "Mentha", "Rosmarinus officinalis", "Petroselinum crispum", "Coriandrum sativum",
    "Lactuca sativa", "Capsicum annuum", "Cucumis sativus", "Fragaria", "Thymus vulgaris",
    "Echinocactus", "Echeveria", "Philodendron", "Dracaena fragrans", "Calathea",
    "Strelitzia", "Aglaonema", "Dypsis lutescens", "Guzmania", "Codiaeum variegatum",
    "Dieffenbachia", "Maranta leuconeura", "Senecio rowleyanus", "Hoya carnosa", "Peperomia",
    "Begonia", "Plectranthus scutellarioides", "Ficus benjamina", "Pelargonium", "Hibiscus rosa-sinensis",
    "Jasminum", "Citrus limon", "Saintpaulia", "Schlumbergera", "Bambusa"
]


class TrefleScraper:
    def __init__(self, api_key: str):
        self.api_key = api_key
        self.base_url = "https://trefle.io/api/v1"
        self.headers = {"Authorization": f"Bearer {api_key}"}
        
    def search_plant(self, plant_name: str) -> Optional[Dict]:
        """Search for a plant by name"""
        try:
            url = f"{self.base_url}/plants/search"
            params = {"q": plant_name, "token": self.api_key}
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            if data.get("data") and len(data["data"]) > 0:
                return data["data"][0]  # Return first match
            return None
            
        except requests.exceptions.RequestException as e:
            print(f"Error searching for {plant_name}: {e}")
            return None
    
    def get_plant_details(self, plant_id: int) -> Optional[Dict]:
        """Get detailed information about a specific plant"""
        try:
            url = f"{self.base_url}/plants/{plant_id}"
            params = {"token": self.api_key}
            
            response = requests.get(url, params=params, timeout=10)
            response.raise_for_status()
            
            data = response.json()
            return data.get("data")
            
        except requests.exceptions.RequestException as e:
            print(f"Error fetching details for plant {plant_id}: {e}")
            return None
    
    def extract_plant_data(self, plant_details: Dict, search_name: str = "") -> Dict:
        """Extract relevant growing conditions from plant details"""
        # Safety check
        if not plant_details or not isinstance(plant_details, dict):
            raise ValueError("Invalid plant_details provided")
        
        # Extract growth data
        growth = plant_details.get("main_species", {})
        if growth:
            growth = growth.get("growth", {}) or {}
        else:
            growth = {}
            
        specifications = plant_details.get("main_species", {})
        if specifications:
            specifications = specifications.get("specifications", {}) or {}
        else:
            specifications = {}
        
        # Get common name, fallback to search name if None
        common_name = plant_details.get("common_name") or search_name or "Unknown"
        
        # Map Trefle data to our schema
        plant_data = {
            "name": common_name,
            "scientific_name": plant_details.get("scientific_name", ""),
            "description": plant_details.get("main_species", {}).get("bibliography", ""),
            
            # Temperature (Trefle uses min/max temp in Celsius)
            "optimal_temperature": self._extract_temperature(growth),
            
            # Humidity (estimated based on atmospheric humidity preference)
            "optimal_humidity": self._extract_humidity(growth),
            
            # Light (convert from light requirement to lux)
            "optimal_light": self._extract_light(growth),
            
            # Water frequency (estimated from soil moisture needs)
            "water_frequency_days": self._extract_water_frequency(growth),
            
            # Care instructions
            "care_instructions": self._build_care_instructions(growth, specifications)
        }
        
        return plant_data
    
    def _extract_temperature(self, growth: Dict) -> float:
        """Extract optimal temperature in Celsius"""
        min_temp = growth.get("minimum_temperature", {}).get("deg_c")
        max_temp = growth.get("maximum_temperature", {}).get("deg_c")
        
        if min_temp and max_temp:
            return (min_temp + max_temp) / 2
        elif min_temp:
            return min_temp + 5  # Estimate
        elif max_temp:
            return max_temp - 5  # Estimate
        
        # Default reasonable temperature
        return 21.0
    
    def _extract_humidity(self, growth: Dict) -> float:
        """Extract optimal humidity percentage"""
        atm_humidity = growth.get("atmospheric_humidity")
        
        humidity_map = {
            1: 30.0,   # Very low
            2: 35.0,   # Low
            3: 40.0,   # Low-medium
            4: 45.0,   # Low-medium
            5: 50.0,   # Medium
            6: 55.0,   # Medium
            7: 60.0,   # Medium-high
            8: 65.0,   # High
            9: 70.0,   # High
            10: 75.0,  # Very high
        }
        
        return humidity_map.get(atm_humidity, 50.0)
    
    def _extract_light(self, growth: Dict) -> float:
        """Extract optimal light in lux"""
        light = growth.get("light")
        
        # Map light requirement (0-10 scale) to lux
        light_map = {
            0: 500.0,     # Shade
            1: 750.0,     # Deep shade
            2: 1000.0,    # Part shade
            3: 1250.0,    # Part shade
            4: 1500.0,    # Part shade / part sun
            5: 2000.0,    # Part sun
            6: 2500.0,    # Part sun
            7: 3000.0,    # Full sun
            8: 4000.0,    # Full sun
            9: 5000.0,    # Full sun
            10: 6000.0,   # Very bright
        }
        
        return light_map.get(light, 2000.0)
    
    def _extract_water_frequency(self, growth: Dict) -> int:
        """Estimate watering frequency in days"""
        moisture = growth.get("soil_humidity")
        
        # Map moisture requirement to watering frequency
        frequency_map = {
            1: 14,   # Very dry - water rarely
            2: 12,   # Dry
            3: 10,   # Dry-medium
            4: 7,    # Medium
            5: 5,    # Medium
            6: 4,    # Medium-moist
            7: 3,    # Moist
            8: 2,    # Moist
            9: 2,    # Very moist
            10: 1,   # Wet
        }
        
        return frequency_map.get(moisture, 5)
    
    def _build_care_instructions(self, growth: Dict, specifications: Dict) -> str:
        """Build care instructions string"""
        instructions = []
        
        if growth.get("description"):
            instructions.append(growth["description"])
        
        if growth.get("soil_texture"):
            instructions.append(f"Soil: {growth['soil_texture']}")
        
        if specifications.get("toxicity"):
            instructions.append(f"Toxicity: {specifications['toxicity']}")
        
        return " | ".join(instructions) if instructions else ""
    
    def scrape_plants(self, plant_names: List[str], delay: float = 1.0) -> List[Dict]:
        """Scrape data for multiple plants"""
        results = []
        
        print(f"Starting to scrape {len(plant_names)} plants...")
        
        for i, plant_name in enumerate(plant_names, 1):
            print(f"[{i}/{len(plant_names)}] Fetching {plant_name}...")
            
            # Search for plant
            search_result = self.search_plant(plant_name)
            if not search_result:
                print(f"  [NOT FOUND] {plant_name}")
                continue
            
            plant_id = search_result.get("id")
            if not plant_id:
                print(f"  [NO ID] {plant_name}")
                continue
            
            # Get detailed data
            time.sleep(delay)  # Respect API rate limits
            plant_details = self.get_plant_details(plant_id)
            
            if not plant_details:
                print(f"  [NO DETAILS] {plant_name}")
                continue
            
            # Extract and format data
            try:
                plant_data = self.extract_plant_data(plant_details, plant_name)
                results.append(plant_data)
            except (AttributeError, KeyError, TypeError) as e:
                print(f"  [ERROR] Parsing data for {plant_name}: {e}")
                continue
            
            print(f"  [SUCCESS] {plant_data['name']} - Temp: {plant_data['optimal_temperature']}°C, "
                  f"Humidity: {plant_data['optimal_humidity']}%, "
                  f"Light: {plant_data['optimal_light']} lux")
            
            # Rate limiting
            time.sleep(delay)
        
        print(f"\n[COMPLETE] Successfully scraped {len(results)}/{len(plant_names)} plants")
        return results
    
    def save_to_json(self, data: List[Dict], filename: str = "plant_data.json"):
        """Save scraped data to JSON file"""
        # Save to project root directory
        filepath = filename
        
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2, ensure_ascii=False)
        
        print(f"[SAVED] Data saved to {filepath}")
        return filepath


def main():
    # Get API key from environment variable
    api_key = os.getenv("TREFLE_API_KEY")
    
    if not api_key:
        print("[ERROR] TREFLE_API_KEY environment variable not set")
        print("Set it with: export TREFLE_API_KEY='your_api_key_here'")
        return
    
    # Initialize scraper
    scraper = TrefleScraper(api_key)
    
    # Scrape plant data
    plant_data = scraper.scrape_plants(COMMON_PLANTS, delay=1.0)
    
    # Save to JSON
    if plant_data:
        scraper.save_to_json(plant_data, "plant_data.json")
        print(f"\n[DONE] Scraped {len(plant_data)} plants successfully!")
    else:
        print("\n[ERROR] No data scraped")


if __name__ == "__main__":
    main()
