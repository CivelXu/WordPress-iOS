import UIKit

@objc
class ReaderCoordinator: NSObject {
    let readerNavigationController: UINavigationController
    let readerSplitViewController: WPSplitViewController
    let readerMenuViewController: ReaderMenuViewController

    var source: UIViewController? = nil {
        didSet {
            isNavigatingFromSource = (source != nil && source == topNavigationController.topViewController)
        }
    }

    private var isNavigatingFromSource = false

    @objc
    init(readerNavigationController: UINavigationController,
         readerSplitViewController: WPSplitViewController,
         readerMenuViewController: ReaderMenuViewController) {
        self.readerNavigationController = readerNavigationController
        self.readerSplitViewController = readerSplitViewController
        self.readerMenuViewController = readerMenuViewController

        super.init()
    }
    private func prepareToNavigate() {
        WPTabBarController.sharedInstance().showReaderTab()

        topNavigationController.popToRootViewController(animated: isNavigatingFromSource)
    }

    func showReaderTab() {
        WPTabBarController.sharedInstance().showReaderTab()
    }

    func showDiscover() {
        prepareToNavigate()

        readerMenuViewController.showSectionForDefaultMenuItem(withOrder: .discover,
                                                               animated: isNavigatingFromSource)
    }

    func showSearch() {
        prepareToNavigate()

        readerMenuViewController.showSectionForDefaultMenuItem(withOrder: .search,
                                                               animated: isNavigatingFromSource)
    }

    func showA8CTeam() {
        prepareToNavigate()

        readerMenuViewController.showSectionForTeam(withSlug: ReaderTeamTopic.a8cTeamSlug, animated: isNavigatingFromSource)
    }

    func showMyLikes() {
        prepareToNavigate()

        readerMenuViewController.showSectionForDefaultMenuItem(withOrder: .likes,
                                                               animated: isNavigatingFromSource)
    }

    func showManageFollowing() {
        prepareToNavigate()

        readerMenuViewController.showSectionForDefaultMenuItem(withOrder: .followed, animated: false)

        if let followedViewController = topNavigationController.topViewController as? ReaderStreamViewController {
            followedViewController.showManageSites(animated: isNavigatingFromSource)
        }
    }

    func showList(named listName: String, forUser user: String) {
        let context = ContextManager.sharedInstance().mainContext
        let service = ReaderTopicService(managedObjectContext: context)

        guard let topic = service.topicForList(named: listName, forUser: user) else {
            return
        }

        prepareToNavigate()

        let streamViewController = ReaderStreamViewController.controllerWithTopic(topic)
        readerSplitViewController.showDetailViewController(streamViewController, sender: nil)
        readerMenuViewController.deselectSelectedRow(animated: false)
    }

    func showTag(named tagName: String) {
        prepareToNavigate()

        let remote = ReaderTopicServiceRemote(wordPressComRestApi: WordPressComRestApi.anonymousApi(userAgent: WPUserAgent.wordPress()))
        let slug = remote.slug(forTopicName: tagName) ?? tagName.lowercased()
        let controller = ReaderStreamViewController.controllerWithTagSlug(slug)

        readerSplitViewController.showDetailViewController(controller, sender: nil)
        readerMenuViewController.deselectSelectedRow(animated: false)
    }

    func showStream(with siteID: Int, isFeed: Bool) {
        prepareToNavigate()

        let controller = ReaderStreamViewController.controllerWithSiteID(NSNumber(value: siteID), isFeed: isFeed)

        readerSplitViewController.showDetailViewController(controller, sender: nil)
        readerMenuViewController.deselectSelectedRow(animated: false)
    }

    func showPost(with postID: Int, for feedID: Int, isFeed: Bool) {
        if !isNavigatingFromSource {
            prepareToNavigate()
        }

        let detailViewController = ReaderDetailViewController.controllerWithPostID(postID as NSNumber,
                                                                                       siteID: feedID as NSNumber,
                                                                                       isFeed: isFeed)

        topNavigationController.pushFullscreenViewController(detailViewController, animated: isNavigatingFromSource)
        readerMenuViewController.deselectSelectedRow(animated: false)
    }

    private var topNavigationController: UINavigationController {
        if readerMenuViewController.splitViewControllerIsHorizontallyCompact == false,
            let navigationController = readerSplitViewController.topDetailViewController?.navigationController {
            return navigationController
        }

        return readerNavigationController
    }
}

private extension ReaderTopicService {
    /// Returns an existing topic for the specified list, or creates one if one
    /// doesn't already exist.
    ///
    func topicForList(named listName: String, forUser user: String) -> ReaderListTopic? {
        let remote = ReaderTopicServiceRemote(wordPressComRestApi: WordPressComRestApi.anonymousApi(userAgent: WPUserAgent.wordPress()))
        let sanitizedListName = remote.slug(forTopicName: listName) ?? listName.lowercased()
        let sanitizedUser = user.lowercased()
        let path = remote.path(forEndpoint: "read/list/\(sanitizedUser)/\(sanitizedListName)/posts", withVersion: ._1_2)

        if let existingTopic = findContainingPath(path) as? ReaderListTopic {
            return existingTopic
        }

        let topic = ReaderListTopic(context: managedObjectContext)
        topic.title = listName
        topic.slug = sanitizedListName
        topic.owner = user
        topic.path = path

        return topic
    }
}
