/// Travel status used to filter aggregated Explore destinations.
///
/// These statuses are independent. A destination can belong to
/// multiple filters without creating duplicate records.
enum ExploreDestinationFilter { all, been, lived, wish, multipleVisits }

/// Sorting options shared by countries and cities.
enum ExploreDestinationSort { nameAscending, nameDescending, mostVisited }
