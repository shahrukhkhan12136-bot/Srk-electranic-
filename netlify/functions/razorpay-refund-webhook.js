const { handler } = require("../../razorpay-refund.js");
exports.handler = async event => ({...await handler({...event,path:"/api/razorpay-refund-webhook"}),headers:{"Content-Type":"application/json; charset=utf-8","Cache-Control":"no-store"}});
