export const getCurrentAppRoute = async () => {
  const url = (await this.client.url()).value;
  return url.substring(url.indexOf('#/') + 1); // return without the hash
};

export const waitUntilUrlEquals = (expectedUrl) => {
  const context = this;
  return context.client.waitUntil(async () => {
    const url = await getCurrentAppRoute.call(context);
    return url === expectedUrl;
  });
};

export const navigateTo = (requestedRoute) => (
  this.client.execute((route) => {
    daedalus.actions.router.goToRoute.trigger({ route });
  }, requestedRoute)
);
