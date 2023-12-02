# TravelTide Data Segmentation Project

![1698052698629](https://github.com/TheoDorokhoff/TravelTide-Customer-segmentation/assets/144614675/f5289c37-fc6d-4a89-8ccd-d49bf3cdf768)



## Summary

This project focuses on designing and implementing a personalized rewards program to enhance customer retention on the TravelTide platform. The goal is to identify customer preferences for five proposed perks: Free hotel meal, Free checked bag, No cancellation fees, Exclusive discount, and 1 free night in the hotel with a flight. The analysis involves categorizing customers into segments aligned with these perks using advanced SQL queries, Fuzzy segmentation technique, and Tableau visualization.

## Methodology

Utilizing advanced SQL queries and Tableau, customers were segmented into five distinct groups based on proposed perks. The analysis considered various customer interactions, outliers were handled using IQR, and MinMax scaling was applied to avoid scale bias. Key metrics were derived from multiple sources, ensuring a comprehensive understanding.

[Tableau workbook](https://public.tableau.com/views/TravelTideprojectworkbook/MealHunterindex?:language=en-US&:display_count=n&:origin=viz_share_link)

[Video presentation](https://youtu.be/Yq3DaToqfdk)

## Key Findings

1.  **Free Hotel Meal Offer (Group size: 933 users):** Identified through the Meal Hunter Index, capturing behaviors of customers interested in extended stays and potential meal-related perks.
    
2.  **Free Checked Bag Offer (Group size: 1673 users):** Identified through the average luggage pieces per user, emphasizing customers interested in travel comfort.
    
3.  **No Cancellation Fee Offer (Group size: 1233 users):** Identified through an index combining cancellation proportions and completed trips, reflecting customer commitment to travel.
    
4.  **1 Night Free Hotel with Flight Offer (Group size: 857 users):** Identified through the maximum distance traveled, indicating customer preference for extended stays with flights.
    
5.  **Exclusive Discounts Offer (Group size: 1302 users):** Identified through the Bargain Hunter Index, amalgamating discounted flight purchases, average discount size, and dollars saved per kilometer, reflecting price-sensitive customers.
    

## Conclusions/Recommendations

The project successfully achieved its objectives, supporting the theory behind the proposed perks. Key insights include the popularity of the "Free Checked Bag" perk, stability in interest for the "Exclusive Discounts" perk, and the lower popularity of the "1 Night Free Hotel with Flight" perk, suggesting a need to prioritize other offers. Further analysis and development recommendations are outlined in the full report.
