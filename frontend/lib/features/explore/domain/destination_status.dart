enum DestinationStatus {
  been,
  lived,
  wish;

  String get label => switch (this) {
    DestinationStatus.been => 'Been',
    DestinationStatus.lived => 'Lived',
    DestinationStatus.wish => 'Wish',
  };

  String get description => switch (this) {
    DestinationStatus.been => 'Record a visit',
    DestinationStatus.lived => 'Record where you lived',
    DestinationStatus.wish => 'Add to your wishlist',
  };
}
