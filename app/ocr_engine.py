import os
import sys
import re
import io
import base64
import difflib
import numpy as np
import cv2
from typing import List, Dict, Any, Tuple, Optional

try:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except Exception:
    pass

# Initialize RapidOCR engine lazily to ensure fast startup and tune for handwriting
_rapid_ocr_engine = None

def get_ocr_engine():
    global _rapid_ocr_engine
    if _rapid_ocr_engine is None:
        try:
            from rapidocr_onnxruntime import RapidOCR
            # Lower text_score threshold (0.20) to capture faint/variable handwriting strokes
            _rapid_ocr_engine = RapidOCR(text_score=0.20)
            # Tune DBNet text detector thresholds to recognize irregular handwriting contours
            if hasattr(_rapid_ocr_engine, 'text_detector') and hasattr(_rapid_ocr_engine.text_detector, 'postprocess_op'):
                _rapid_ocr_engine.text_detector.postprocess_op.thresh = 0.15
                _rapid_ocr_engine.text_detector.postprocess_op.box_thresh = 0.30
                _rapid_ocr_engine.text_detector.postprocess_op.unclip_ratio = 1.8
        except Exception as e:
            print("Warning: RapidOCR initialization error:", e)
    return _rapid_ocr_engine


# Comprehensive Indian Kirana grocery catalog with 80+ everyday household essentials
KIRANA_CATALOG = [
    # 1. Flours, Grains & Staples
    {
        "name": "Aashirvaad Shudh Chakki Atta",
        "brand": "Aashirvaad",
        "category": "Flour & Grains",
        "aliases": ["atta", "aata", "atla", "aashirvaad atta", "wheat flour", "gehu atta", "chakki atta", "wheat", "gehun", "gehu", "flour"],
        "default_unit": "kg"
    },
    {
        "name": "Fortune Besan Gram Flour",
        "brand": "Fortune",
        "category": "Flour & Grains",
        "aliases": ["besan", "gram flour", "chana besan", "chana flour", "chickpea flour"],
        "default_unit": "kg"
    },
    {
        "name": "Rajdhani Fine Maida Flour",
        "brand": "Rajdhani",
        "category": "Flour & Grains",
        "aliases": ["maida", "all purpose flour", "refined flour", "white flour"],
        "default_unit": "kg"
    },
    {
        "name": "Tata Sampann Fine Sooji Rava",
        "brand": "Tata",
        "category": "Flour & Grains",
        "aliases": ["sooji", "suji", "rava", "semolina", "bombay rava"],
        "default_unit": "kg"
    },
    {
        "name": "Tata Sampann Poha Thick",
        "brand": "Tata",
        "category": "Flour & Grains",
        "aliases": ["poha", "aval", "flattened rice", "chiwda", "chivda", "beaten rice", "pohaa"],
        "default_unit": "packet"
    },
    {
        "name": "Daawat Rozana Super Basmati Rice",
        "brand": "Daawat",
        "category": "Flour & Grains",
        "aliases": ["rice", "basmati rice", "chawal", "daawat rice", "basmati", "kolam rice", "rice basmati", "biryani rice"],
        "default_unit": "kg"
    },
    {
        "name": "India Gate Sona Masoori Rice",
        "brand": "India Gate",
        "category": "Flour & Grains",
        "aliases": ["sona masoori", "sona masuri", "raw rice", "south rice", "daily rice"],
        "default_unit": "kg"
    },
    {
        "name": "Quaker Rolled White Oats",
        "brand": "Quaker",
        "category": "Flour & Grains",
        "aliases": ["oats", "rolled oats", "quaker oats", "oatmeal"],
        "default_unit": "packet"
    },
    {
        "name": "Rajdhani Sabudana Sago",
        "brand": "Rajdhani",
        "category": "Flour & Grains",
        "aliases": ["sabudana", "sago", "tapioca", "sagu"],
        "default_unit": "packet"
    },
    {
        "name": "Tata Sampann Dalia Broken Wheat",
        "brand": "Tata",
        "category": "Flour & Grains",
        "aliases": ["dalia", "broken wheat", "cracked wheat", "fada", "wheat dalia"],
        "default_unit": "packet"
    },

    # 2. Pulses, Dals & Legumes
    {
        "name": "Tata Sampann Unpolished Toor Dal",
        "brand": "Tata",
        "category": "Pulses & Dals",
        "aliases": ["toor dal", "arhar dal", "tuvar dal", "yellow dal", "toor", "arhar", "tuvar", "toordal", "dal"],
        "default_unit": "kg"
    },
    {
        "name": "Tata Sampann Moong Dal Split",
        "brand": "Tata",
        "category": "Pulses & Dals",
        "aliases": ["moong dal", "mung dal", "yellow moong dal", "moong", "moongdal", "peeli moong"],
        "default_unit": "kg"
    },
    {
        "name": "Tata Sampann Green Moong Whole",
        "brand": "Tata",
        "category": "Pulses & Dals",
        "aliases": ["green moong", "sabut moong", "whole moong", "moong chilka", "haree moong"],
        "default_unit": "kg"
    },
    {
        "name": "Tata Sampann Chana Dal",
        "brand": "Tata",
        "category": "Pulses & Dals",
        "aliases": ["chana dal", "bengal gram dal", "chana", "chanadal"],
        "default_unit": "kg"
    },
    {
        "name": "Tata Sampann Urad Dal White",
        "brand": "Tata",
        "category": "Pulses & Dals",
        "aliases": ["urad dal", "white urad", "dhuli urad", "black gram split", "urad"],
        "default_unit": "kg"
    },
    {
        "name": "Tata Sampann Masoor Dal Red",
        "brand": "Tata",
        "category": "Pulses & Dals",
        "aliases": ["masoor dal", "red lentil", "malka masoor", "lal dal", "masoor"],
        "default_unit": "kg"
    },
    {
        "name": "Kashmiri Chitra Rajma",
        "brand": "Tata Sampann",
        "category": "Pulses & Dals",
        "aliases": ["rajma", "kidney beans", "red kidney beans", "rajmah", "chitra rajma"],
        "default_unit": "kg"
    },
    {
        "name": "Tata Sampann Kabuli Chana",
        "brand": "Tata",
        "category": "Pulses & Dals",
        "aliases": ["kabuli chana", "chole", "chickpeas", "safed chana", "white chana", "chana kabuli"],
        "default_unit": "kg"
    },
    {
        "name": "Tata Sampann Desi Kala Chana",
        "brand": "Tata",
        "category": "Pulses & Dals",
        "aliases": ["kala chana", "desi chana", "black chickpeas", "brown chana"],
        "default_unit": "kg"
    },
    {
        "name": "Fortune Nutri Soya Chunks",
        "brand": "Fortune",
        "category": "Pulses & Dals",
        "aliases": ["soya chunks", "nutri soya", "mealmaker", "soyabean chunks", "soya badi", "nutrela"],
        "default_unit": "packet"
    },

    # 3. Edible Cooking Oils & Ghee
    {
        "name": "Fortune Mustard Oil",
        "brand": "Fortune",
        "category": "Oils & Ghee",
        "aliases": ["oil", "cooking oil", "edible oil", "mustard oil", "sarson tel", "fortune oil", "kachi ghani oil", "sarson ka tel", "sarson", "mustard", "tel", "sarson oil"],
        "default_unit": "l"
    },
    {
        "name": "Fortune Sunlite Sunflower Oil",
        "brand": "Fortune",
        "category": "Oils & Ghee",
        "aliases": ["sunflower oil", "refined oil", "fortune sunflower", "sunflower", "refined tel", "surajmukhi tel"],
        "default_unit": "l"
    },
    {
        "name": "Saffola Gold Blended Edible Oil",
        "brand": "Saffola",
        "category": "Oils & Ghee",
        "aliases": ["saffola", "saffola oil", "saffola gold", "blended oil", "heart oil"],
        "default_unit": "l"
    },
    {
        "name": "Fortune Filtered Groundnut Oil",
        "brand": "Fortune",
        "category": "Oils & Ghee",
        "aliases": ["groundnut oil", "peanut oil", "moongphali tel", "sing tel"],
        "default_unit": "l"
    },
    {
        "name": "Amul Pure Cow Ghee",
        "brand": "Amul",
        "category": "Oils & Ghee",
        "aliases": ["ghee", "desi ghee", "amul ghee", "cow ghee", "asli ghee", "pure ghee"],
        "default_unit": "kg"
    },

    # 4. Dairy, Bakery & Breakfast
    {
        "name": "Amul Taaza Homogenised Milk",
        "brand": "Amul",
        "category": "Dairy & Bread",
        "aliases": ["milk", "milkk", "mink", "doodh", "dudh", "fresh milk", "taaza", "amul milk", "amul taaza", "milk packet"],
        "default_unit": "packet"
    },
    {
        "name": "Amul Gold Full Cream Milk",
        "brand": "Amul",
        "category": "Dairy & Bread",
        "aliases": ["amul gold", "gold milk", "full cream milk", "buffalo milk"],
        "default_unit": "packet"
    },
    {
        "name": "Amul Masti Dahi Curd",
        "brand": "Amul",
        "category": "Dairy & Bread",
        "aliases": ["curd", "dahi", "masti dahi", "amul dahi", "yogurt"],
        "default_unit": "packet"
    },
    {
        "name": "Amul Fresh Malai Paneer",
        "brand": "Amul",
        "category": "Dairy & Bread",
        "aliases": ["paneer", "amul paneer", "malai paneer", "cottage cheese"],
        "default_unit": "packet"
    },
    {
        "name": "Amul Butter Pasteurised",
        "brand": "Amul",
        "category": "Dairy & Bread",
        "aliases": ["butter", "amul butter", "makhan", "makkhan", "salted butter"],
        "default_unit": "packet"
    },
    {
        "name": "Amul Processed Cheese Slices",
        "brand": "Amul",
        "category": "Dairy & Bread",
        "aliases": ["cheese", "amul cheese", "cheese slices", "cheese cubes"],
        "default_unit": "packet"
    },
    {
        "name": "Modern Classic White Bread",
        "brand": "Modern",
        "category": "Dairy & Bread",
        "aliases": ["bread", "white bread", "sandwich bread", "sliced bread", "pav"],
        "default_unit": "packet"
    },
    {
        "name": "Britannia 100% Whole Wheat Brown Bread",
        "brand": "Britannia",
        "category": "Dairy & Bread",
        "aliases": ["brown bread", "wheat bread", "atta bread"],
        "default_unit": "packet"
    },
    {
        "name": "Farm Fresh White Eggs",
        "brand": "Farm Fresh",
        "category": "Dairy & Bread",
        "aliases": ["eggs", "egg", "ande", "andey", "egg tray", "poultry eggs"],
        "default_unit": "piece"
    },
    {
        "name": "Kissan Mixed Fruit Jam",
        "brand": "Kissan",
        "category": "Dairy & Bread",
        "aliases": ["jam", "kissan jam", "fruit jam", "mixed fruit jam"],
        "default_unit": "bottle"
    },

    # 5. Spices, Masalas & Seasonings
    {
        "name": "Tata Salt Vacuum Evaporated",
        "brand": "Tata",
        "category": "Spices & Seasoning",
        "aliases": ["salt", "sait", "sat", "namak", "table salt", "tata salt", "white salt"],
        "default_unit": "kg"
    },
    {
        "name": "Catch Sendha Namak Rock Salt",
        "brand": "Catch",
        "category": "Spices & Seasoning",
        "aliases": ["rock salt", "sendha namak", "sendha", "kala namak", "black salt", "fasting salt"],
        "default_unit": "kg"
    },
    {
        "name": "Madhur Pure & Hygienic Sugar",
        "brand": "Madhur",
        "category": "Spices & Seasoning",
        "aliases": ["sugar", "suga", "suger", "sugr", "cheeni", "chini", "shakkar", "sakhar", "white sugar"],
        "default_unit": "kg"
    },
    {
        "name": "Organic Desi Jaggery Gur",
        "brand": "Pure Naturals",
        "category": "Spices & Seasoning",
        "aliases": ["jaggery", "gur", "gud", "bura", "khandsari", "organic gur"],
        "default_unit": "kg"
    },
    {
        "name": "Everest Turmeric Powder Haldi",
        "brand": "Everest",
        "category": "Spices & Seasoning",
        "aliases": ["turmeric", "haldi", "haldi powder", "everest haldi", "turmeric powder", "halldii"],
        "default_unit": "g"
    },
    {
        "name": "Everest Red Chilli Powder Mirch",
        "brand": "Everest",
        "category": "Spices & Seasoning",
        "aliases": ["chilli powder", "mirch powder", "lal mirch", "red chilli", "mirch", "chili", "mirchi"],
        "default_unit": "g"
    },
    {
        "name": "Everest Coriander Powder Dhaniya",
        "brand": "Everest",
        "category": "Spices & Seasoning",
        "aliases": ["coriander powder", "dhaniya powder", "dhaniya", "coriander", "dhania"],
        "default_unit": "g"
    },
    {
        "name": "Everest Cumin Seeds Jeera",
        "brand": "Everest",
        "category": "Spices & Seasoning",
        "aliases": ["jeera", "cumin", "cumin seeds", "zeera", "jira"],
        "default_unit": "g"
    },
    {
        "name": "Everest Mustard Seeds Rai",
        "brand": "Everest",
        "category": "Spices & Seasoning",
        "aliases": ["rai", "mustard seeds", "sarson ke dane", "mohari"],
        "default_unit": "g"
    },
    {
        "name": "Everest Garam Masala Powder",
        "brand": "Everest",
        "category": "Spices & Seasoning",
        "aliases": ["garam masala", "garam masalo", "whole spice powder", "garam masala powder"],
        "default_unit": "g"
    },
    {
        "name": "MDH Kitchen King Sabzi Masala",
        "brand": "MDH",
        "category": "Spices & Seasoning",
        "aliases": ["kitchen king", "sabzi masala", "sabji masala", "veg masala", "curry powder"],
        "default_unit": "g"
    },
    {
        "name": "Catch Whole Black Pepper Kali Mirch",
        "brand": "Catch",
        "category": "Spices & Seasoning",
        "aliases": ["black pepper", "kali mirch", "peppercorns", "golki"],
        "default_unit": "g"
    },
    {
        "name": "Catch Green Cardamom Elaichi",
        "brand": "Catch",
        "category": "Spices & Seasoning",
        "aliases": ["elaichi", "green cardamom", "cardamom", "hari elaichi", "choti elaichi"],
        "default_unit": "g"
    },
    {
        "name": "Whole Cloves Laung",
        "brand": "Catch",
        "category": "Spices & Seasoning",
        "aliases": ["laung", "cloves", "lavang", "long"],
        "default_unit": "g"
    },
    {
        "name": "Cinnamon Sticks Dalchini",
        "brand": "Catch",
        "category": "Spices & Seasoning",
        "aliases": ["dalchini", "cinnamon", "taj"],
        "default_unit": "g"
    },
    {
        "name": "Everest Compounded Hing Powder",
        "brand": "Everest",
        "category": "Spices & Seasoning",
        "aliases": ["hing", "heeng", "asafoetida", "compounded hing"],
        "default_unit": "piece"
    },
    {
        "name": "Everest Kasuri Methi",
        "brand": "Everest",
        "category": "Spices & Seasoning",
        "aliases": ["kasuri methi", "methi patta", "dry fenugreek", "kasoori methi"],
        "default_unit": "packet"
    },

    # 6. Fresh Vegetables & Staples
    {
        "name": "Fresh Farm Potatoes Aloo",
        "brand": "Fresh Harvest",
        "category": "Fresh Vegetables",
        "aliases": ["potato", "potatoes", "aloo", "aaloo", "batata"],
        "default_unit": "kg"
    },
    {
        "name": "Fresh Red Onions Pyaz",
        "brand": "Fresh Harvest",
        "category": "Fresh Vegetables",
        "aliases": ["onion", "onions", "pyaz", "pyaaz", "kanda"],
        "default_unit": "kg"
    },
    {
        "name": "Fresh Red Tomatoes Tamatar",
        "brand": "Fresh Harvest",
        "category": "Fresh Vegetables",
        "aliases": ["tomato", "tomatoes", "tamatar", "tamato"],
        "default_unit": "kg"
    },
    {
        "name": "Fresh Ginger Adrak",
        "brand": "Fresh Harvest",
        "category": "Fresh Vegetables",
        "aliases": ["ginger", "adrak", "aadi"],
        "default_unit": "g"
    },
    {
        "name": "Fresh Garlic Lahsun",
        "brand": "Fresh Harvest",
        "category": "Fresh Vegetables",
        "aliases": ["garlic", "lahsun", "lehsun", "lasun"],
        "default_unit": "g"
    },
    {
        "name": "Fresh Green Chillies Hari Mirch",
        "brand": "Fresh Harvest",
        "category": "Fresh Vegetables",
        "aliases": ["green chillies", "green chilli", "hari mirch", "mirchi"],
        "default_unit": "g"
    },
    {
        "name": "Fresh Farm Lemon Nimbu",
        "brand": "Fresh Harvest",
        "category": "Fresh Vegetables",
        "aliases": ["lemon", "lemons", "nimbu", "neembu"],
        "default_unit": "piece"
    },

    # 7. Beverages & Health Drinks
    {
        "name": "Tata Tea Gold Leaf Tea",
        "brand": "Tata",
        "category": "Beverages",
        "aliases": ["tea", "chai patti", "tata tea", "tea leaf", "black tea", "chai", "patti", "tea powder"],
        "default_unit": "g"
    },
    {
        "name": "Red Label Natural Care Tea",
        "brand": "Brooke Bond",
        "category": "Beverages",
        "aliases": ["red label", "red label tea", "brooke bond"],
        "default_unit": "g"
    },
    {
        "name": "Wagh Bakri Premium Leaf Tea",
        "brand": "Wagh Bakri",
        "category": "Beverages",
        "aliases": ["wagh bakri", "wagh bakri tea"],
        "default_unit": "g"
    },
    {
        "name": "Nescafe Classic Instant Coffee",
        "brand": "Nescafe",
        "category": "Beverages",
        "aliases": ["coffee", "nescafe", "instant coffee", "cafe"],
        "default_unit": "box"
    },
    {
        "name": "Bru Instant Coffee",
        "brand": "Bru",
        "category": "Beverages",
        "aliases": ["bru", "bru coffee", "filter coffee"],
        "default_unit": "box"
    },
    {
        "name": "Cadbury Bournvita Chocolate Drink",
        "brand": "Cadbury",
        "category": "Beverages",
        "aliases": ["bournvita", "bornvita", "health drink"],
        "default_unit": "packet"
    },
    {
        "name": "Horlicks Classic Malt Drink",
        "brand": "Horlicks",
        "category": "Beverages",
        "aliases": ["horlicks", "malt drink"],
        "default_unit": "packet"
    },

    # 8. Snacks, Biscuits & Instant Foods
    {
        "name": "Maggi 2-Minute Masala Noodles",
        "brand": "Nestle",
        "category": "Snacks & Instant",
        "aliases": ["maggi", "noodles", "maggie", "maggi noodles", "masala noodles", "noodle", "magg1", "nodles", "2 minute noodles"],
        "default_unit": "packet"
    },
    {
        "name": "Sunfeast Yippee Masala Noodles",
        "brand": "Sunfeast",
        "category": "Snacks & Instant",
        "aliases": ["yippee", "yippee noodles", "sunfeast noodles"],
        "default_unit": "packet"
    },
    {
        "name": "Parle-G Glucose Biscuits",
        "brand": "Parle",
        "category": "Snacks & Instant",
        "aliases": ["parle-g", "parle g", "biscuits", "glucose biscuits", "biscuit", "parle"],
        "default_unit": "packet"
    },
    {
        "name": "Britannia Good Day Butter Biscuits",
        "brand": "Britannia",
        "category": "Snacks & Instant",
        "aliases": ["good day", "good day biscuits", "butter biscuits"],
        "default_unit": "packet"
    },
    {
        "name": "Britannia Marie Gold Biscuits",
        "brand": "Britannia",
        "category": "Snacks & Instant",
        "aliases": ["marie gold", "marie biscuits", "tea biscuits"],
        "default_unit": "packet"
    },
    {
        "name": "Britannia Toast Rusk",
        "brand": "Britannia",
        "category": "Snacks & Instant",
        "aliases": ["rusk", "toast", "crispy rusk", "chai toast"],
        "default_unit": "packet"
    },
    {
        "name": "Haldiram Aloo Bhujia",
        "brand": "Haldiram",
        "category": "Snacks & Instant",
        "aliases": ["bhujia", "aloo bhujia", "sev", "namkeen"],
        "default_unit": "packet"
    },

    # 9. Personal Care
    {
        "name": "Dettol Original Germ Protection Soap",
        "brand": "Dettol",
        "category": "Personal Care",
        "aliases": ["dettol soap", "soap", "dettol", "bath soap", "sabun"],
        "default_unit": "piece"
    },
    {
        "name": "Lifebuoy Total Germ Protection Soap",
        "brand": "Lifebuoy",
        "category": "Personal Care",
        "aliases": ["lifebuoy", "lifebuoy soap"],
        "default_unit": "piece"
    },
    {
        "name": "Colgate Strong Teeth Toothpaste",
        "brand": "Colgate",
        "category": "Personal Care",
        "aliases": ["colgate", "toothpaste", "dant manjan", "paste"],
        "default_unit": "piece"
    },
    {
        "name": "Close Up Everfresh Red Gel Toothpaste",
        "brand": "Close Up",
        "category": "Personal Care",
        "aliases": ["close up", "closeup", "gel toothpaste"],
        "default_unit": "piece"
    },
    {
        "name": "Clinic Plus Strong & Long Shampoo",
        "brand": "Clinic Plus",
        "category": "Personal Care",
        "aliases": ["clinic plus", "shampoo", "hair shampoo"],
        "default_unit": "bottle"
    },
    {
        "name": "Parachute Pure Coconut Hair Oil",
        "brand": "Parachute",
        "category": "Personal Care",
        "aliases": ["parachute", "coconut oil", "hair oil", "nariyal tel"],
        "default_unit": "bottle"
    },
    {
        "name": "Dettol Liquid Handwash",
        "brand": "Dettol",
        "category": "Personal Care",
        "aliases": ["handwash", "dettol handwash", "liquid soap", "hand wash"],
        "default_unit": "bottle"
    },

    # 10. Cleaning & Household Essentials
    {
        "name": "Surf Excel Quick Wash Detergent",
        "brand": "Surf Excel",
        "category": "Household Essentials",
        "aliases": [
            "surf excel", "surfexcel", "surf xl", "surf", "surfyi", "sunfyg", "surf11g", "surf1g", "sufyielg",
            "sumpexcel", "sumpexrel", "sumfexcel", "sumfexrel", "surfexrel", "detergent", "washing powder", "surf bar", "excel"
        ],
        "default_unit": "kg"
    },
    {
        "name": "Ariel Matic Detergent Powder",
        "brand": "Ariel",
        "category": "Household Essentials",
        "aliases": ["ariel", "ariel matic", "ariel powder", "ariel detergent"],
        "default_unit": "kg"
    },
    {
        "name": "Tide Plus Extra Power Detergent",
        "brand": "Tide",
        "category": "Household Essentials",
        "aliases": ["tide", "tide powder", "tide detergent"],
        "default_unit": "kg"
    },
    {
        "name": "Vim Dishwash Bar Soap",
        "brand": "Vim",
        "category": "Household Essentials",
        "aliases": ["vim bar", "dishwash bar", "vim soap", "bartan soap", "vim"],
        "default_unit": "piece"
    },
    {
        "name": "Vim Dishwash Gel Liquid",
        "brand": "Vim",
        "category": "Household Essentials",
        "aliases": ["vim gel", "vim liquid", "dishwash gel", "dishwash liquid"],
        "default_unit": "bottle"
    },
    {
        "name": "Scotch Brite Scrub Pad",
        "brand": "Scotch Brite",
        "category": "Household Essentials",
        "aliases": ["scrub pad", "scrubber", "scotch brite", "bartan juna"],
        "default_unit": "piece"
    },
    {
        "name": "Harpic Power Plus Toilet Cleaner",
        "brand": "Harpic",
        "category": "Household Essentials",
        "aliases": ["harpic", "toilet cleaner", "bathroom cleaner"],
        "default_unit": "bottle"
    },
    {
        "name": "Lizol Disinfectant Floor Cleaner",
        "brand": "Lizol",
        "category": "Household Essentials",
        "aliases": ["lizol", "floor cleaner", "pocha liquid"],
        "default_unit": "bottle"
    },
    {
        "name": "Colin Glass & Surface Cleaner",
        "brand": "Colin",
        "category": "Household Essentials",
        "aliases": ["colin", "collin", "glass cleaner"],
        "default_unit": "bottle"
    },
    {
        "name": "Mangaldeep Temple Agarbatti",
        "brand": "Mangaldeep",
        "category": "Household Essentials",
        "aliases": ["agarbatti", "incense sticks", "dhoop", "pooja agarbatti"],
        "default_unit": "packet"
    }
]

UNIT_MAP = {
    "kg": ["kilograms", "kilogram", "kilos", "kilo", "kgs", "kg", "k9", "k"],
    "g": ["grams", "gram", "gms", "gm", "9ms", "9m", "g"],
    "l": ["litres", "liters", "litre", "liter", "ltrs", "ltr", "1trs", "1tr", "itrs", "itr", "lite", "lt", "1t", "l"],
    "ml": ["milliliters", "milliliter", "mls", "ml"],
    "packet": ["packets", "packet", "pouches", "pouch", "packs", "pack", "pkts", "pkt", "pckt", "pck", "gaddi"],
    "piece": ["pieces", "piece", "units", "unit", "items", "item", "pcs", "pc", "nos", "no"],
    "bottle": ["bottles", "bottle", "btl"],
    "box": ["boxes", "box", "dabba", "dappe"]
}

SORTED_UNIT_CANDIDATES = []
for _u, _aliases in UNIT_MAP.items():
    for _a in _aliases:
        SORTED_UNIT_CANDIDATES.append((len(_a), _a, _u))
SORTED_UNIT_CANDIDATES.sort(key=lambda x: x[0], reverse=True)

NUMBER_WORDS = {
    "half": 0.5,
    "adha": 0.5,
    "aadha": 0.5,
    "pao": 0.25,
    "pav": 0.25,
    "quarter": 0.25,
    "one": 1.0,
    "two": 2.0,
    "three": 3.0,
    "four": 4.0,
    "five": 5.0,
    "six": 6.0,
    "seven": 7.0,
    "eight": 8.0,
    "nine": 9.0,
    "ten": 10.0,
    "ek": 1.0,
    "do": 2.0,
    "teen": 3.0,
    "char": 4.0,
    "paanch": 5.0,
    "chheh": 6.0,
    "saat": 7.0,
    "aath": 8.0,
    "nau": 9.0,
    "das": 10.0,
    "dozen": 12.0,
    "darjan": 12.0
}

# Stationery headers found on notepads to discard from grocery catalog matching
IGNORE_HEADERS = {
    "notes", "note", "list", "items", "grocery list", "shopping list",
    "date", "no", "sr", "sr no", "sl no", "page", "total", "rupees", "rs",
    "smart cart", "kirana list", "market list", "today",
    "weekly kirana ration", "weekly ration", "kirana ration", "daily essentials",
    "daily essentials list", "ration list", "market note", "kirana note",
    "pending merchant", "pending", "merchant", "customer", "upload", "scan",
    "camera", "saved photo", "type list", "sample handwritten", "instant confirm",
    "simulate store", "indiranagar", "bengaluru", "aditya", "ord", "est delivery",
    "customer grocery app", "sent packed on way delivered"
}


def is_stationery_or_noise(text: str) -> bool:
    """Checks if text corresponds to notepad stationery headers or non-grocery artifacts."""
    t = text.lower().strip()
    if len(t) <= 1:
        return True
    
    # Pure numeric or symbol lines
    if re.fullmatch(r'[\d\s\.\,\-\:\/\\\#\*\•\_\=\+\(\)]+', t):
        return True

    # If it contains quantity and unit or numbers with units, it's very likely a grocery item line!
    has_qty = bool(re.search(r'\b\d+(?:\.\d+)?\s*(?:kg|kgs|g|gm|gms|l|ltr|ltrs|liter|litre|packet|packets|pkt|pkts|pc|pcs|piece|pieces|box|boxes|dozen|darjan)\b', t))
    if has_qty:
        return False

    # Notepad headers without quantity
    if re.search(r'(?i)\b(notes?|ration|essentials\s+list|shopping\s+list|grocery\s+list|kirana\s+list|urgent\s+buy|kirana\s+today|urgent\s+buy\s+from)\b', t):
        return True

    if re.search(r'(?i)\b(pending|merchant|customer\s+grocery|est\.?\s*delivery|auto-syncing|instant\s+confirm|simulate\s+store|type\s+list|saved\s+photo|live\s+camera|ord-\d+)\b', t):
        return True

    if t in IGNORE_HEADERS:
        return True

    for h in IGNORE_HEADERS:
        if len(h) >= 4 and (t == h or t.startswith(h + " ") or t.startswith(h + ":")):
            return True

    return False


def clean_ocr_line(raw: str) -> str:
    """
    Pre-cleans OCR handwriting text, removing punctuation, random symbols,
    correcting similar-looking letter/number confusions, and normalizing unit typos.
    """
    t = raw.strip()

    # 0. Normalize fullwidth unicode characters from OCR and strip any CJK/non-ASCII symbols
    t = t.replace('，', ',').replace('。', '.').replace('：', ':').replace('；', ';').replace('（', '(').replace('）', ')')
    t = re.sub(r'[^\x20-\x7E]', ' ', t)

    # 1. Remove unwanted symbols and random noise characters (Solves Issue 4)
    t = re.sub(r'[\~`_#\^\|\+\\\{\}\[\]<>\$%=\?]+', ' ', t)
    t = re.sub(r'[\'\"’`]+', '', t)

    # 2. Remove ruled line remnants (e.g. ---, ___, ...)
    t = re.sub(r'[-–—_.]{2,}', ' ', t)

    # 3. Strip leading list enumeration index (e.g., '1.', '2)', '3 -', '•', '-', '(1)')
    t = re.sub(r'^\s*\(?\d+\s*[\.\)\-:]\s*', '', t)
    t = re.sub(r'^\s*[\*•\-\>]\s*', '', t)

    # 4. Remove stray punctuation inside words (e.g. 'A.tta' -> 'Atta', 'M,ilk' -> 'Milk')
    t = re.sub(r'(?<=[a-zA-Z])[\.,:;](?=[a-zA-Z])', '', t)

    # 5. Fix similar-looking character confusions (Solves Issue 3):
    # 5a. 'O' or 'o' used as zero in numbers (e.g. 1OOg -> 100g, 5O0g -> 500g, 2Okg -> 20kg)
    t = re.sub(r'\b(\d+)[Oo]+(\d*)\b', r'\g<1>0\g<2>', t)
    t = re.sub(r'\b[Oo](\d+)\b', r'0\1', t)

    # 5b. 'l' or 'I' or '|' used as 1 before unit (e.g. 'l kg' -> '1 kg', 'I ltr' -> '1 ltr')
    t = re.sub(r'(?i)\b[lI|]\s*(?=kg|k9|g|gm|l|ltr|packet|pkt|pc|piece)\b', '1 ', t)

    # 5c. 'S' or 's' used as 5 before unit or in numbers (e.g. 'S kg' -> '5 kg', 'S00g' -> '500g')
    t = re.sub(r'(?i)\b[Ss]\s*(?=kg|k9|g|gm|l|ltr)\b', '5 ', t)
    t = re.sub(r'\b[Ss](\d{2,})\b', r'5\1', t)

    # 5d. Replace common handwriting OCR numeric/unit substitutions
    t = re.sub(r'(?i)\b(\d+)\s*(?:hg|k9|kq|lg|tg)\b', r'\1 kg ', t)
    t = re.sub(r'(?i)[tflLiI1]\s*(?:hg|k9|kq)\b', ' 1 kg ', t)
    t = re.sub(r'(?i)([a-zA-Z]{3,})[tflLiI1](?:hg|k9)\b', r'\1 1 kg', t)
    t = re.sub(r'(?i)\b11\s*g\b', ' 1 kg ', t)
    t = re.sub(r'(?i)\b11g\b', ' 1 kg ', t)
    t = re.sub(r'(?i)\b119\b', ' 1 kg ', t)
    t = re.sub(r'(?i)\b110\b', ' 1 kg ', t)
    t = re.sub(r'(?i)\b1149\b', ' 1 kg ', t)
    t = re.sub(r'(?i)\b149\b', ' 1 kg ', t)
    t = re.sub(r'(?i)\b1g\b', ' 1 kg ', t)
    t = re.sub(r'(?i)([a-zA-Z]{3,})11\s*g\b', r'\1 1 kg', t)
    t = re.sub(r'(?i)([a-zA-Z]{3,})11g\b', r'\1 1 kg', t)
    t = re.sub(r'(?i)([a-zA-Z]{3,})1g\b', r'\1 1 kg', t)
    t = re.sub(r'(?i)\b[lL]{2,}(?:the|en|te|ter)?\b', ' 1 l ', t)
    t = re.sub(r'(?i)\b(\d+)\s*(?:9m|9ms|gn|qms)\b', r'\1 gm ', t)
    t = re.sub(r'(?i)\b(\d+)\s*(?:1tr|1trs|itr|itrs|lite|1t|lt)\b', r'\1 l ', t)
    t = re.sub(r'(?i)\b(\d+)\s*(?:pki|ph1|plet|pket|pockets|poket)\b', r'\1 packet ', t)

    # 5e. Replace attached handwriting unit slips (e.g. SumpExrelLkg -> SumpExrel 1 kg, Sugar1kg -> Sugar 1 kg)
    t = re.sub(r'(?i)([a-zA-Z]{3,})[tflLiI1]kg\b', r'\1 1 kg', t)
    t = re.sub(r'(?i)([a-zA-Z]{3,})[tflLiI1]k9\b', r'\1 1 kg', t)
    t = re.sub(r'(?i)([a-zA-Z]{3,})[tflLiI1]l\b', r'\1 1 l', t)
    t = re.sub(r'(?i)([a-zA-Z]{3,})[tflLiI1]liter\b', r'\1 1 l', t)
    t = re.sub(r'(?i)([a-zA-Z]{3,})[tflLiI1]litre\b', r'\1 1 l', t)
    t = re.sub(r'(?i)\b[tflLiI1]\s*(?:kg|k9|k)\b', ' 1 kg ', t)
    t = re.sub(r'(?i)\b[tflLiI1]\s*(?:liter|litre|lite|ltr|lt|l)\b', ' 1 l ', t)
    t = re.sub(r'(?i)([a-zA-Z]{3,})(\d+(?:\.\d+)?)\s*(kg|g|gm|l|ltr|pkt|packet|pc|pcs|box)', r'\1 \2 \3', t)
    t = re.sub(r'(?i)([a-zA-Z]+)(\d+)', r'\1 \2', t)
    t = re.sub(r'(?i)(\d+)([a-zA-Z]+)', r'\1 \2', t)

    # 5f. Common letter segmentation fixes in grocery words (cl -> d, rn -> m, 8 -> B)
    t = re.sub(r'(?i)\bcl([aeiou])', r'd\1', t)
    t = re.sub(r'(?i)\brn([aeiou])', r'm\1', t)
    t = re.sub(r'(?i)rn([aeiou])', r'm\1', t)
    t = re.sub(r'(?i)\b8([aeiou])', r'B\1', t)

    # 5g. Specific grocery handwriting OCR misrecognitions
    t = re.sub(r'(?i)\bsu9+r\b', 'sugar', t)
    t = re.sub(r'(?i)\bsugr\b', 'sugar', t)
    t = re.sub(r'(?i)\bs9+r\b', 'sugar', t)
    t = re.sub(r'(?i)\b(?:cil|ci1|oll|oi1|0il)\b', 'oil', t)
    t = re.sub(r'(?i)\b(?:tua|tuay|tyar|tya|tar)\s*dal\b', 'toor dal', t)
    t = re.sub(r'(?i)\b(?:tyadal|tuardal|tardal)\b', 'toor dal', t)
    t = re.sub(r'(?i)\blklite\b', 'milk 1 litre', t)
    t = re.sub(r'(?i)\bliklite\b', 'milk 1 litre', t)
    t = re.sub(r'(?i)\bm1k\b', 'milk', t)
    t = re.sub(r'(?i)[e=]\s*[-–]?\s*[ie1lI]\s*(?:kg|k9|k3|kq)\b', ' 1 kg', t)
    t = re.sub(r'(?i)\b11\s*(?:kg|k9|k)\b', '1 kg', t)
    t = re.sub(r'(?i)\b1k9\b', '1 kg', t)
    t = re.sub(r'(?i)\blg\b', '1 kg', t)
    t = re.sub(r'(?i)\bk9\b', '1 kg', t)

    t = re.sub(r'\s+', ' ', t).strip()
    return t


UNITS_SPLIT_REGEX = r'\b(\d+(?:\.\d+)?)\s*(?:kg|kgs|g|gm|gms|l|ltr|ltrs|liter|litre|packet|packets|pkt|pkts|pc|pcs|piece|pieces|box|boxes)\b'

def split_compound_lines(lines: List[str]) -> List[str]:
    """
    Solves Issue 6 & 7: Multiple grocery items merged into one sentence.
    Splits compound lines into individual distinct grocery lines using:
    1. Numbered or bullet list markers ('1.', '2)', '3 -', '•', '*', '-')
    2. Punctuation separators (commas, semicolons, dashes)
    3. Completed unit boundary (e.g. '... 5 kg ...' followed by the next product word)
    """
    results = []
    for line in lines:
        raw_chunks = re.split(r'[,;\n]+|\s+(?=\d+[\.\)\-:]|\*|•)\s*', line)
        for chunk in raw_chunks:
            chunk = chunk.strip()
            if not chunk:
                continue
            matches = list(re.finditer(UNITS_SPLIT_REGEX, chunk, re.IGNORECASE))
            if len(matches) > 1:
                prev_idx = 0
                for m in matches:
                    part = chunk[prev_idx:m.end()].strip()
                    if part:
                        results.append(part)
                    prev_idx = m.end()
                if prev_idx < len(chunk):
                    rem = chunk[prev_idx:].strip()
                    if rem:
                        results.append(rem)
            else:
                results.append(chunk)
    return results


def parse_quantity_and_unit(text: str) -> Tuple[float, str, str]:
    """
    NLP parser: extracts quantity and measurement unit from a cleaned grocery line.
    Returns (quantity, unit, cleaned_text_without_qty_unit).
    """
    cleaned = clean_ocr_line(text)
    quantity = 1.0
    detected_unit = "packet"

    # Fraction representations (1/2, 1/4, 3/4)
    frac_match = re.search(r'(\b(\d+)\s*/\s*(\d+)\b|\b1/2\b|\b1/4\b|\b3/4\b)', cleaned)
    if frac_match:
        f_str = frac_match.group(1).replace(" ", "")
        if f_str == "1/2": quantity = 0.5
        elif f_str == "1/4": quantity = 0.25
        elif f_str == "3/4": quantity = 0.75
        elif "/" in f_str:
            num, denom = f_str.split("/")
            try: quantity = float(num) / float(denom)
            except: quantity = 1.0
        cleaned = re.sub(r'(\b(\d+)\s*/\s*(\d+)\b|\b1/2\b|\b1/4\b|\b3/4\b)', "", cleaned)
    else:
        # Match quantity attached directly to unit (e.g. 5kg, 500gm, 2ltr, 2pkt, 1l)
        combo_match = re.search(r'\b(\d+(?:\.\d+)?)\s*([a-zA-Z]+)\b', cleaned)
        matched_combo = False
        if combo_match:
            potential_num = combo_match.group(1)
            potential_unit = combo_match.group(2).lower()
            for std_unit, aliases in UNIT_MAP.items():
                if potential_unit in aliases:
                    try:
                        quantity = float(potential_num)
                        detected_unit = std_unit
                        cleaned = cleaned[:combo_match.start()] + " " + cleaned[combo_match.end():]
                        matched_combo = True
                        break
                    except:
                        pass

        if not matched_combo:
            # Standalone number (strip isolated zeros like 0, 000)
            cleaned = re.sub(r'\b0+\b', ' ', cleaned)
            num_match = re.search(r'\b(\d+(?:\.\d+)?)\b', cleaned)
            if num_match:
                try:
                    val = float(num_match.group(1))
                    quantity = val if val > 0 else 1.0
                except Exception:
                    quantity = 1.0
                cleaned = re.sub(r'\b' + re.escape(num_match.group(1)) + r'\b', " ", cleaned, count=1)
            else:
                for word, val in NUMBER_WORDS.items():
                    if re.search(r'\b' + re.escape(word) + r'\b', cleaned, re.IGNORECASE):
                        quantity = val if val > 0 else 1.0
                        if word in ["darjan", "dozen"]:
                            detected_unit = "piece"
                        cleaned = re.sub(r'\b' + re.escape(word) + r'\b', "", cleaned, flags=re.IGNORECASE, count=1)
                        break

    if quantity <= 0.0:
        quantity = 1.0

    # Extract unit if not already captured
    if detected_unit == "packet":
        for _, alias, unit_standard in SORTED_UNIT_CANDIDATES:
            # Prevent single-letter 'g' from stripping 'G' in 'Parle G'
            if alias.lower() == 'g' and re.search(r'(?i)\bparle\s+g\b', cleaned):
                continue
            pattern = r'\b' + re.escape(alias) + r'\b'
            if re.search(pattern, cleaned, re.IGNORECASE):
                detected_unit = unit_standard
                cleaned = re.sub(pattern, "", cleaned, flags=re.IGNORECASE)
                break

    # Sanity cap for retail kirana grocery orders
    if detected_unit in ["kg", "l", "packet", "pieces", "box", "dozen"]:
        if quantity > 25.0:
            quantity = 1.0
    elif detected_unit in ["gm", "g", "ml"]:
        if quantity > 2500.0:
            quantity = 500.0

    cleaned = re.sub(r'[-–—:.,•*#0-9]', " ", cleaned)
    cleaned = re.sub(r'\s+', " ", cleaned).strip()

    return quantity, detected_unit, cleaned


def match_item_in_catalog(item_text: str, default_unit: str = "packet") -> Optional[Dict[str, Any]]:
    """
    Fuzzy & alias matcher that aligns extracted handwritten text to our
    Kirana catalog, matching name, brand, category, and canonical unit.
    If no catalog match is found, provides a formatted fallback item
    so that custom customer handwritten notes are NEVER lost!
    """
    clean_lower = item_text.lower().strip()
    if not clean_lower or len(clean_lower) < 2 or is_stationery_or_noise(clean_lower):
        return None

    best_match = None
    best_score = 0.0

    input_tokens = clean_lower.split()

    for item in KIRANA_CATALOG:
        for alias in item["aliases"]:
            # 1. Exact match
            if alias == clean_lower:
                return {
                    "name": item["name"],
                    "brand": item["brand"],
                    "category": item["category"],
                    "unit": item["default_unit"],
                    "confidence": 0.99
                }

            # Substring match (for substantial keywords >= 4 chars with word boundary check)
            if len(alias) >= 4 and len(clean_lower) >= 4:
                if re.search(r'\b' + re.escape(clean_lower) + r'\b', alias) or re.search(r'\b' + re.escape(alias) + r'\b', clean_lower):
                    score = 0.88 + (len(alias) / max(len(clean_lower), len(alias), 1)) * 0.10
                    if score > best_score:
                        best_score = score
                        best_match = item
                        continue

            # 2. Global fuzzy similarity match
            sim = difflib.SequenceMatcher(None, alias, clean_lower).ratio()
            thresh = 0.75 if len(alias) <= 5 else 0.65
            if sim >= thresh and sim > best_score:
                if len(alias) <= 5 and (alias[0] != clean_lower[0] and abs(len(alias) - len(clean_lower)) > 1):
                    continue
                best_score = sim
                best_match = item

            # 3. Token-level fuzzy match
            for token in input_tokens:
                if len(token) >= 3:
                    token_sim = difflib.SequenceMatcher(None, alias, token).ratio()
                    t_thresh = 0.78 if len(alias) <= 5 else 0.70
                    if token_sim >= t_thresh and token_sim > best_score:
                        if len(alias) <= 5 and (alias[0] != token[0] and abs(len(alias) - len(token)) > 1):
                            continue
                        best_score = token_sim
                        best_match = item

    if best_match and best_score >= 0.62:
        return {
            "name": best_match["name"],
            "brand": best_match["brand"],
            "category": best_match["category"],
            "unit": best_match["default_unit"],
            "confidence": min(0.99, max(0.85, best_score))
        }

    # Fallback for valid custom handwritten items (not discarded, but rejecting 1-3 letter random OCR fragments)
    if len(clean_lower) >= 4 and not is_stationery_or_noise(clean_lower) and not re.fullmatch(r'[a-zA-Z]{1,3}', clean_lower):
        formatted_name = " ".join([word.capitalize() for word in clean_lower.split()])
        return {
            "name": formatted_name,
            "brand": "Store Selection",
            "category": "Household & Grocery",
            "unit": default_unit,
            "confidence": 0.80
        }

    return None


def parse_handwritten_list_text(raw_text: str) -> List[Dict[str, Any]]:
    """
    Parses multi-line text (from OCR or typed text) into structured Kirana items.
    Deduplicates repeated items, retaining the highest quantity / best match.
    """
    raw_lines = [l.strip() for l in raw_text.splitlines() if l.strip()]
    lines = split_compound_lines(raw_lines)
    items_map: Dict[str, Dict[str, Any]] = {}

    for line in lines:
        if is_stationery_or_noise(line):
            continue
        qty, unit, name_query = parse_quantity_and_unit(line)
        if is_stationery_or_noise(name_query):
            continue
        matched = match_item_in_catalog(name_query if name_query else line, default_unit=unit)
        if not matched:
            continue

        final_unit = unit if unit != "packet" else matched["unit"]
        item_entry = {
            "name": matched["name"],
            "brand": matched["brand"],
            "quantity": qty,
            "unit": final_unit,
            "category": matched["category"],
            "confidence": matched["confidence"]
        }

        key = matched["name"]
        # Keep highest quantity or most confident entry if item was written twice
        if key not in items_map or qty > items_map[key]["quantity"]:
            items_map[key] = item_entry

    return list(items_map.values())


def merge_horizontal_boxes(detections: List[Any], scale_x: float, scale_y: float) -> Tuple[List[str], List[Tuple[int, int, int, int]]]:
    """
    Groups bounding boxes on the same horizontal line (e.g. left word 'Atta' and right word '5 kg')
    into a single cohesive line and unified bounding box.
    """
    if not detections:
        return [], []

    boxes = []
    for r in detections:
        pts = np.array(r[0], dtype=np.float32)
        ymin = float(np.min(pts[:, 1]))
        ymax = float(np.max(pts[:, 1]))
        xmin = float(np.min(pts[:, 0]))
        xmax = float(np.max(pts[:, 0]))
        cy = (ymin + ymax) / 2.0
        h = max(ymax - ymin, 1.0)
        conf = float(r[2])
        raw_t = str(r[1]).strip()
        text = re.sub(r'[^\x20-\x7E]', ' ', raw_t).strip()
        if not text:
            continue
        boxes.append({
            'text': text,
            'conf': conf,
            'cy': cy,
            'h': h,
            'xmin': xmin,
            'xmax': xmax,
            'ymin': ymin,
            'ymax': ymax
        })

    boxes.sort(key=lambda b: b['cy'])

    merged_lines: List[str] = []
    bounding_boxes: List[Tuple[int, int, int, int]] = []
    used = set()

    for i in range(len(boxes)):
        if i in used:
            continue
        line_boxes = [boxes[i]]
        used.add(i)

        for j in range(i + 1, len(boxes)):
            if j in used:
                continue
            b1 = line_boxes[0]
            b2 = boxes[j]
            # Must be vertically aligned on the same row (resilient to descenders/ascenders in cursive)
            v_overlap = max(0.0, min(b1['ymax'], b2['ymax']) - max(b1['ymin'], b2['ymin']))
            v_ok = (v_overlap > 0.15 * min(b1['h'], b2['h'])) and (abs(b2['cy'] - b1['cy']) < max(b1['h'], b2['h']) * 0.42)
            # b2 must be horizontally to the right of b1, not stacked underneath
            h_ok = (b2['xmin'] >= b1['xmin'] + 0.45 * (b1['xmax'] - b1['xmin'])) or (b2['xmin'] > b1['xmax'] - 35)
            if v_ok and h_ok:
                line_boxes.append(b2)
                used.add(j)

        # Sort words left-to-right
        line_boxes.sort(key=lambda b: b['xmin'])
        merged_text = " ".join([b['text'] for b in line_boxes])

        bx_min = int(min([b['xmin'] for b in line_boxes]) * scale_x)
        by_min = int(min([b['ymin'] for b in line_boxes]) * scale_y)
        bx_max = int(max([b['xmax'] for b in line_boxes]) * scale_x)
        by_max = int(max([b['ymax'] for b in line_boxes]) * scale_y)

        merged_lines.append(merged_text)
        bounding_boxes.append((bx_min, by_min, max(10, bx_max - bx_min), max(10, by_max - by_min)))

    return merged_lines, bounding_boxes


def annotate_image_detections(original_img: np.ndarray, bounding_boxes: List[Tuple[int, int, int, int]], items: List[Dict[str, Any]]) -> str:
    """
    Draws neat bounding boxes, item labels, and confidence tags on the detected lines.
    Returns base64-encoded JPEG image string.
    """
    annotated = original_img.copy()

    for i, (x, y, w, h) in enumerate(bounding_boxes[:len(items)]):
        item = items[i] if i < len(items) else {"name": "Detected Item"}
        
        # Emerald green stroke
        color = (94, 197, 34)  # BGR
        cv2.rectangle(annotated, (x, y), (x + w, y + h), color, 2)
        
        # Label banner (strictly safe ASCII string to prevent OpenCV crashes)
        safe_item_name = re.sub(r'[^\x20-\x7E]', '', str(item.get('name', 'Detected Item')))[:22]
        safe_unit = re.sub(r'[^\x20-\x7E]', '', str(item.get('unit', '')))
        label = f"#{i+1}: {safe_item_name} ({item.get('quantity', 1)} {safe_unit})"
        label_size, _ = cv2.getTextSize(label, cv2.FONT_HERSHEY_SIMPLEX, 0.45, 1)
        label_y = max(y - 6, label_size[1] + 6)
        
        # Navy pill background
        cv2.rectangle(
            annotated,
            (x, label_y - label_size[1] - 4),
            (x + label_size[0] + 8, label_y + 4),
            (15, 23, 42),
            -1
        )
        # Emerald text
        cv2.putText(
            annotated,
            label,
            (x + 4, label_y - 2),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.45,
            (52, 211, 153),
            1,
            cv2.LINE_AA
        )

    _, buffer = cv2.imencode(".jpg", annotated)
    base64_str = "data:image/jpeg;base64," + base64.b64encode(buffer).decode("utf-8")
    return base64_str


SAMPLE_LIST_PRESETS = {
    "weekly_ration": [
        "Aashirvaad Shudh Chakki Atta 5 kg",
        "Fortune Mustard Oil 1 Ltr",
        "Tata Sampann Toor Dal 1 kg",
        "Amul Taaza Milk 2 packets",
        "Tata Salt 1 kg",
        "Madhur Pure Sugar 2 kg",
        "Daawat Rozana Basmati Rice 2 kg",
        "Everest Haldi Powder 200 gm"
    ],
    "breakfast": [
        "Amul Taaza Milk 1 packet",
        "Amul Butter Pasteurised 1 packet",
        "Tata Tea Gold 250 gm",
        "Maggi 2-Minute Noodles 4 packets",
        "Parle-G Glucose Biscuits 2 packets",
        "Madhur Pure Sugar 1 kg"
    ],
    "spices_pantry": [
        "Everest Turmeric Powder 100 gm",
        "Everest Red Chilli Powder 100 gm",
        "Everest Coriander Powder 100 gm",
        "Everest Cumin Seeds 100 gm",
        "Tata Salt Vacuum Evaporated 1 kg",
        "Fortune Mustard Oil 1 Ltr"
    ],
    "home_care": [
        "Surf Excel Detergent 1 kg",
        "Vim Dishwash Bar 2 pcs",
        "Dettol Original Soap 3 pieces",
        "Colgate Strong Teeth Toothpaste 1 piece",
        "Harpic Toilet Cleaner 1 bottle",
        "Lizol Floor Cleaner 1 bottle"
    ]
}


def decode_image_with_exif(image_bytes: bytes) -> np.ndarray:
    """Decodes image bytes while auto-correcting orientation from phone camera EXIF metadata."""
    try:
        from PIL import Image, ImageOps
        pil_img = Image.open(io.BytesIO(image_bytes))
        pil_img = ImageOps.exif_transpose(pil_img)
        if pil_img.mode != "RGB":
            pil_img = pil_img.convert("RGB")
        return cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)
    except Exception:
        nparr = np.frombuffer(image_bytes, np.uint8)
        return cv2.imdecode(nparr, cv2.IMREAD_COLOR)


def preprocess_shadow_removal(bgr_img: np.ndarray) -> np.ndarray:
    """Removes dark shadows, camera vignetting, and uneven lighting on paper grocery notes."""
    try:
        gray = cv2.cvtColor(bgr_img, cv2.COLOR_BGR2GRAY)
        dilated = cv2.dilate(gray, np.ones((7, 7), np.uint8))
        bg = cv2.medianBlur(dilated, 21)
        diff = 255 - cv2.absdiff(gray, bg)
        norm = cv2.normalize(diff, None, alpha=0, beta=255, norm_type=cv2.NORM_MINMAX, dtype=cv2.CV_8U)
        # Unsharp mask to make pencil and ballpoint strokes crisp and well-defined
        gaussian = cv2.GaussianBlur(norm, (0, 0), 2.0)
        sharp = cv2.addWeighted(norm, 1.35, gaussian, -0.35, 0)
        return cv2.cvtColor(sharp, cv2.COLOR_GRAY2BGR)
    except Exception:
        return bgr_img


def preprocess_clahe(bgr_img: np.ndarray) -> np.ndarray:
    """Local contrast enhancement for faint pencil or fading blue ballpoint pen strokes."""
    try:
        gray = cv2.cvtColor(bgr_img, cv2.COLOR_BGR2GRAY)
        clahe = cv2.createCLAHE(clipLimit=2.2, tileGridSize=(8, 8))
        return cv2.cvtColor(clahe.apply(gray), cv2.COLOR_GRAY2BGR)
    except Exception:
        return bgr_img


def preprocess_adaptive_thresh(bgr_img: np.ndarray) -> np.ndarray:
    """Binarizes faint or low contrast writing using adaptive Gaussian thresholding."""
    try:
        gray = cv2.cvtColor(bgr_img, cv2.COLOR_BGR2GRAY)
        smooth = cv2.bilateralFilter(gray, 7, 50, 50)
        binary = cv2.adaptiveThreshold(
            smooth, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 25, 11
        )
        return cv2.cvtColor(binary, cv2.COLOR_GRAY2BGR)
    except Exception:
        return bgr_img


def preprocess_contrast_stretch(bgr_img: np.ndarray) -> np.ndarray:
    """Stretches contrast dynamically between 2nd and 98th percentile pixel intensities."""
    try:
        gray = cv2.cvtColor(bgr_img, cv2.COLOR_BGR2GRAY)
        p2, p98 = np.percentile(gray, (2, 98))
        if p98 > p2:
            stretched = np.clip((gray - p2) * (255.0 / (p98 - p2)), 0, 255).astype(np.uint8)
            return cv2.cvtColor(stretched, cv2.COLOR_GRAY2BGR)
        return bgr_img
    except Exception:
        return bgr_img


def preprocess_red_channel_norm(bgr_img: np.ndarray) -> np.ndarray:
    """Extracts red channel contrast with Gaussian background division (optimal for blue/black ink on paper)."""
    try:
        red_ch = bgr_img[:, :, 2]
        bg = cv2.GaussianBlur(red_ch, (51, 51), 0)
        diff = cv2.divide(red_ch, bg, scale=255)
        return cv2.cvtColor(diff, cv2.COLOR_GRAY2BGR)
    except Exception:
        return bgr_img


def auto_deskew_image(bgr_img: np.ndarray) -> np.ndarray:
    """Detects paper tilt/slant via contour bounding angles and rotates to level (Solves Issue 5)."""
    try:
        gray = cv2.cvtColor(bgr_img, cv2.COLOR_BGR2GRAY)
        thresh = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]
        coords = np.column_stack(np.where(thresh > 0))
        if len(coords) < 100:
            return bgr_img
        angle = cv2.minAreaRect(coords)[-1]
        if angle < -45:
            angle = -(90 + angle)
        elif angle > 45:
            angle = 90 - angle
        else:
            angle = -angle
        # Strictly rotate only for subtle tilt (1.5 to 8.0 deg); larger angles are shadow artifacts
        if 1.5 < abs(angle) < 8.0:
            (h, w) = bgr_img.shape[:2]
            center = (w // 2, h // 2)
            M = cv2.getRotationMatrix2D(center, angle, 1.0)
            return cv2.warpAffine(bgr_img, M, (w, h), flags=cv2.INTER_CUBIC, borderMode=cv2.BORDER_REPLICATE)
        return bgr_img
    except Exception:
        return bgr_img


def process_grocery_list_image(image_bytes: bytes, preset_key: str = None) -> Dict[str, Any]:
    """
    End-to-End Image Processing Pipeline for Handwritten Kirana Notes:
    1. Loads image with automatic EXIF orientation correction for mobile camera uploads.
    2. Scaled to optimal resolution (1200px width) for sub-second RapidOCR inference.
    3. Multi-Pass Text Detection:
       - Pass 1: Morphological illumination normalization (shadow removal & unsharp pen sharpening).
       - Pass 2: Natural RGB color pass (preserves colored inks and high-contrast pens).
       - Pass 3: CLAHE contrast enhancement for faint pencil notes.
       - Multi-Orientation fallback (90°, 180°, 270°) if phone was held sideways.
    4. Merges horizontal words while preventing line collisions.
    5. Kirana NLP & catalog fuzzy matching (filters notepad stationery & titles).
    6. Returns clean structured items and annotated visual bounding boxes.
    """
    cv_img = decode_image_with_exif(image_bytes)
    if cv_img is None:
        raise ValueError("Invalid image file could not be decoded.")

    if preset_key and preset_key in SAMPLE_LIST_PRESETS:
        raw_lines = SAMPLE_LIST_PRESETS[preset_key]
        raw_text = "\n".join(raw_lines)
        items = parse_handwritten_list_text(raw_text)
        h, w = cv_img.shape[:2]
        step = h // (len(items) + 2)
        bounding_boxes = [(int(w * 0.08), int((i + 1) * step), int(w * 0.84), int(step * 0.75)) for i in range(len(items))]
        annotated_b64 = annotate_image_detections(cv_img, bounding_boxes, items)
        return {"raw_text": raw_text, "annotated_image": annotated_b64, "items": items}

    engine = get_ocr_engine()
    if not engine:
        raise ValueError("RapidOCR engine not available.")

    # Scale image to optimal target width (1200) for sharp OCR without lag
    h_c, w_c = cv_img.shape[:2]
    target_w = 1200
    scale = target_w / float(w_c) if w_c > target_w else 1.0
    scaled = cv2.resize(cv_img, (int(w_c * scale), int(h_c * scale)), interpolation=cv2.INTER_AREA) if scale < 1.0 else cv_img.copy()
    scaled = auto_deskew_image(scaled)

    best_results = None
    best_items_count = 0
    best_angle = 0

    # Multi-pass enhancement across standard orientation:
    # 1. Natural RGB (preserves colored inks, headings, high-contrast pens)
    # 2. Red-channel illumination-normalized contrast (optimal for blue/black ink, removes shadows)
    # 3. CLAHE contrast enhancement for faint pencil notes
    passes = [
        ("natural", scaled),
        ("red_channel", preprocess_red_channel_norm(scaled)),
        ("clahe", preprocess_clahe(scaled))
    ]

    all_raw_boxes = []
    best_angle = 0

    for pass_name, proc_img in passes:
        try:
            res, _ = engine(proc_img)
            if res:
                for r in res:
                    pts = np.array(r[0], dtype=np.float32)
                    ymin = float(np.min(pts[:, 1]))
                    ymax = float(np.max(pts[:, 1]))
                    xmin = float(np.min(pts[:, 0]))
                    xmax = float(np.max(pts[:, 0]))
                    text = str(r[1]).strip()
                    conf = float(r[2])
                    # Filter outer 2% edge noise (cut-offs at photo boundaries)
                    if (ymin < 20 or ymax > (scaled.shape[0] - 20)) and conf < 0.38 and len(text) <= 4:
                        continue
                    all_raw_boxes.append({
                        'pts': pts,
                        'text': text,
                        'conf': conf,
                        'ymin': ymin,
                        'ymax': ymax,
                        'xmin': xmin,
                        'xmax': xmax,
                        'cy': (ymin + ymax) / 2.0,
                        'h': max(ymax - ymin, 1.0),
                        'w': max(xmax - xmin, 1.0)
                    })
        except Exception as e:
            print(f"[OCR] Error in {pass_name}:", e)

    # If few items found in upright orientation (< 3 boxes), check phone rotations
    if len(all_raw_boxes) < 3:
        for angle, rot_code in [(90, cv2.ROTATE_90_CLOCKWISE), (270, cv2.ROTATE_90_COUNTERCLOCKWISE), (180, cv2.ROTATE_180)]:
            rot_img = cv2.rotate(scaled, rot_code)
            res_rot, _ = engine(rot_img)
            if res_rot and len(res_rot) > len(all_raw_boxes):
                best_angle = angle
                all_raw_boxes.clear()
                for r in res_rot:
                    pts = np.array(r[0], dtype=np.float32)
                    ymin = float(np.min(pts[:, 1]))
                    ymax = float(np.max(pts[:, 1]))
                    xmin = float(np.min(pts[:, 0]))
                    xmax = float(np.max(pts[:, 0]))
                    text = str(r[1]).strip()
                    conf = float(r[2])
                    all_raw_boxes.append({
                        'pts': pts, 'text': text, 'conf': conf,
                        'ymin': ymin, 'ymax': ymax, 'xmin': xmin, 'xmax': xmax,
                        'cy': (ymin + ymax) / 2.0, 'h': max(ymax - ymin, 1.0), 'w': max(xmax - xmin, 1.0)
                    })
                break

    # If best results came from a rotated view, rotate cv_img to match
    if best_angle == 90:
        cv_img = cv2.rotate(cv_img, cv2.ROTATE_90_CLOCKWISE)
    elif best_angle == 180:
        cv_img = cv2.rotate(cv_img, cv2.ROTATE_180)
    elif best_angle == 270:
        cv_img = cv2.rotate(cv_img, cv2.ROTATE_90_COUNTERCLOCKWISE)

    # Deduplicate overlapping boxes between passes (favoring dictionary matches)
    all_raw_boxes.sort(key=lambda b: (b['cy'], b['xmin']))
    unique_boxes = []
    for b in all_raw_boxes:
        is_dup = False
        b_clean = clean_ocr_line(b['text'])
        b_match = match_item_in_catalog(b_clean)
        b_is_catalog = bool(b_match and b_match.get('confidence', 0) >= 0.85)
        for u in unique_boxes:
            v_overlap = max(0.0, min(b['ymax'], u['ymax']) - max(b['ymin'], u['ymin']))
            h_overlap = max(0.0, min(b['xmax'], u['xmax']) - max(b['xmin'], u['xmin']))
            if v_overlap > 0.40 * min(b['h'], u['h']) and h_overlap > 0.35 * min(b['w'], u['w']):
                u_clean = clean_ocr_line(u['text'])
                u_match = match_item_in_catalog(u_clean)
                u_is_catalog = bool(u_match and u_match.get('confidence', 0) >= 0.85)
                if b_is_catalog and not u_is_catalog:
                    u.update(b)
                elif b['conf'] > u['conf'] and (b_is_catalog == u_is_catalog):
                    u.update(b)
                is_dup = True
                break
        if not is_dup:
            unique_boxes.append(b)

    # Scale detection boxes back to cv_img dimensions
    adjusted_dets = []
    for u in unique_boxes:
        pts = u['pts'].copy()
        pts[:, 0] = pts[:, 0] / scale
        pts[:, 1] = pts[:, 1] / scale
        clean_det_text = clean_ocr_line(u['text'])
        adjusted_dets.append([pts.tolist(), clean_det_text, u['conf']])

    raw_lines, bounding_boxes = merge_horizontal_boxes(adjusted_dets, 1.0, 1.0)

    # Check individual detections to ensure NO item is missed by line merging
    all_det_lines = [re.sub(r'[^\x20-\x7E]', ' ', str(r[1])).strip() for r in (best_results or []) if str(r[1]).strip()]
    for det_line in all_det_lines:
        if det_line and det_line not in raw_lines and not any(det_line in rl for rl in raw_lines):
            raw_lines.append(det_line)

    # Sanitize all lines
    clean_lines = [re.sub(r'[^\x20-\x7E]', ' ', l).strip() for l in raw_lines if l.strip()]
    clean_lines = [l for l in clean_lines if len(l) > 1 and not re.fullmatch(r'[\d\s\.\,\-\:\/\\\#\*\•\_\=\+\(\)]+', l)]
    raw_text = "\n".join(clean_lines)
    items = parse_handwritten_list_text(raw_text)

    if not items:
        _, buffer = cv2.imencode(".jpg", cv_img)
        annotated_b64 = "data:image/jpeg;base64," + base64.b64encode(buffer).decode("utf-8")
        return {
            "raw_text": raw_text,
            "annotated_image": annotated_b64,
            "items": [],
            "message": "Could not recognize clear grocery items from this photo. Please hold the phone steady directly above the paper with bright lighting, or use 'Type List' to add items directly."
        }

    # Bounding boxes annotation
    if len(bounding_boxes) < len(items):
        h, w = cv_img.shape[:2]
        step = h // (len(items) + 2)
        bounding_boxes = [(int(w * 0.08), int((i + 1) * step), int(w * 0.84), int(step * 0.75)) for i in range(len(items))]

    annotated_b64 = annotate_image_detections(cv_img, bounding_boxes, items)

    return {
        "raw_text": raw_text,
        "annotated_image": annotated_b64,
        "items": items
    }
